defmodule Frameshift.Diagnostics.FallbackLog do
  @moduledoc "Admits the local rotating fallback log path before OTP opens it."

  @doc "Creates a private diagnostics directory and refuses unsafe existing targets."
  @spec prepare(String.t()) :: :ok | {:error, :unsafe_fallback_log}
  def prepare(path) when is_binary(path) do
    directory = Path.dirname(path)

    with :ok <- File.mkdir_p(directory),
         {:ok, %File.Stat{type: :directory}} <- File.lstat(directory),
         :ok <- File.chmod(directory, 0o700),
         {:ok, %File.Stat{type: :directory, mode: mode}} <- File.lstat(directory),
         true <- Bitwise.band(mode, 0o077) == 0,
         :ok <- prepare_target(path) do
      :ok
    else
      _ -> {:error, :unsafe_fallback_log}
    end
  end

  def prepare(_), do: {:error, :unsafe_fallback_log}

  @doc "Restricts the regular file created by the OTP handler to owner-only access."
  @spec secure_file(String.t()) :: :ok | {:error, :unsafe_fallback_log}
  def secure_file(path) when is_binary(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular}} ->
        case File.chmod(path, 0o600) do
          :ok -> :ok
          _ -> {:error, :unsafe_fallback_log}
        end

      _ ->
        {:error, :unsafe_fallback_log}
    end
  end

  def secure_file(_), do: {:error, :unsafe_fallback_log}

  defp prepare_target(path) do
    case File.lstat(path) do
      {:error, :enoent} -> :ok
      {:ok, %File.Stat{type: :regular}} -> secure_file(path)
      _ -> {:error, :unsafe_fallback_log}
    end
  end
end
