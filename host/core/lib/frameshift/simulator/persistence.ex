defmodule Frameshift.Simulator.Persistence do
  @moduledoc """
  Recovers simulated frame state from redundant, checksummed records.

  A damaged latest slot does not erase an older valid state. This models the
  frame's power-loss recovery rules without treating the simulator as proof of
  physical flash or panel behavior.
  """

  alias Frameshift.Digest
  alias Frameshift.Simulator.State

  @spec load(String.t()) :: :empty | {:ok, map()} | {:error, :corrupt_state}
  def load(data_dir) do
    valid_slots =
      data_dir
      |> slot_paths()
      |> Enum.flat_map(fn path ->
        case read_slot(path) do
          {:ok, payload} -> [payload]
          :invalid -> []
        end
      end)

    case valid_slots do
      [] ->
        if Enum.any?(slot_paths(data_dir), &File.exists?/1),
          do: {:error, :corrupt_state},
          else: :empty

      payloads ->
        {:ok, Enum.max_by(payloads, & &1["stateRevision"])}
    end
  end

  @spec save(State.t()) :: :ok | {:error, term()}
  def save(state) do
    payload = State.persisted(state)
    checksum = payload |> RFC8785.encode!() |> Digest.sha256()
    wrapper = RFC8785.encode!(%{"checksum" => checksum, "payload" => payload})
    target = slot_path(state.data_dir, state.revision)
    temporary = "#{target}.#{System.unique_integer([:positive])}.tmp"

    with :ok <- write_synced(temporary, wrapper),
         :ok <- File.rename(temporary, target) do
      :ok
    else
      {:error, reason} ->
        File.rm(temporary)
        {:error, reason}
    end
  end

  defp read_slot(path) do
    with {:ok, bytes} <- File.read(path),
         {:ok, %{"checksum" => checksum, "payload" => payload}} <- RFC8785.decode(bytes),
         true <- Digest.sha256(RFC8785.encode!(payload)) == checksum,
         revision when is_integer(revision) and revision >= 0 <- payload["stateRevision"] do
      {:ok, payload}
    else
      _reason -> :invalid
    end
  end

  defp write_synced(path, bytes) do
    case File.open(path, [:write, :binary, :exclusive]) do
      {:ok, file} ->
        try do
          with :ok <- IO.binwrite(file, bytes),
               do: :file.sync(file)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp slot_paths(data_dir), do: [slot_path(data_dir, 0), slot_path(data_dir, 1)]

  defp slot_path(data_dir, revision) do
    suffix = if rem(revision, 2) == 0, do: "a", else: "b"
    Path.join(data_dir, "frame-state-#{suffix}.json")
  end
end
