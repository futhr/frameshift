defmodule Frameshift.Pairing.Store do
  @moduledoc """
  Persists the frame's pairing authority as one fail-closed record.

  Pairing cannot use the display simulator's recover-older-slot strategy: an
  older slot could resurrect a consumed bootstrap secret. This store replaces
  one private record atomically and refuses to start when that record is
  damaged. The simulator cannot prove directory-entry durability on every
  filesystem. Firmware must provide protected, rollback-resistant storage
  and prove its own power-loss behavior separately.
  """

  alias Frameshift.Digest
  alias Frameshift.Pairing.Window

  @filename "pairing-authority.json"

  @doc "Loads the authority, or creates it once from a device-owned secret."
  @spec load_or_create(String.t(), String.t(), binary() | nil) ::
          {:ok, Window.t() | nil} | {:error, term()}
  def load_or_create(data_dir, device_id, secret) do
    path = Path.join(data_dir, @filename)

    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular, mode: mode}} when Bitwise.band(mode, 0o077) == 0 ->
        with {:ok, bytes} <- File.read(path), do: decode(bytes, device_id)

      {:ok, _other} ->
        {:error, :insecure_pairing_authority}

      {:error, :enoent} ->
        create(data_dir, device_id, secret)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Atomically replaces the authority before a pairing response is released."
  @spec save(String.t(), Window.t()) :: :ok | {:error, term()}
  def save(data_dir, %Window{} = window) do
    payload = payload(window)
    checksum = payload |> RFC8785.encode!() |> Digest.sha256()
    bytes = RFC8785.encode!(%{"checksum" => checksum, "payload" => payload})
    target = Path.join(data_dir, @filename)
    temporary = "#{target}.#{System.unique_integer([:positive])}.tmp"

    case write_private_synced(temporary, bytes) do
      :ok ->
        result = commit(temporary, target, data_dir)
        File.rm(temporary)
        result

      {:error, reason} ->
        File.rm(temporary)
        {:error, reason}
    end
  end

  defp commit(temporary, target, data_dir) do
    with :ok <- File.rename(temporary, target) do
      case sync_directory(data_dir) do
        :ok -> :ok
        {:error, reason} -> {:error, {:commit_uncertain, reason}}
      end
    end
  end

  defp create(_data_dir, _device_id, nil), do: {:ok, nil}

  defp create(data_dir, device_id, secret) do
    with {:ok, window} <- Window.new(device_id, secret),
         :ok <- save(data_dir, window) do
      {:ok, window}
    end
  end

  defp payload(window) do
    %{
      "version" => 1,
      "deviceId" => window.device_id,
      "secret" => if(window.secret, do: Base.encode64(window.secret), else: nil),
      "hostCertificateFingerprint" => window.host_certificate_fingerprint,
      "pairedRequestId" => window.paired_request_id,
      "attempts" => window.attempts
    }
  end

  defp decode(bytes, expected_device_id) when byte_size(bytes) <= 2_048 do
    with {:ok, %{"checksum" => checksum, "payload" => payload}} <- RFC8785.decode(bytes),
         true <- Digest.sha256(RFC8785.encode!(payload)) == checksum,
         {:ok, window} <- from_payload(payload, expected_device_id) do
      {:ok, window}
    else
      _invalid -> {:error, :corrupt_pairing_authority}
    end
  end

  defp decode(_bytes, _expected_device_id), do: {:error, :corrupt_pairing_authority}

  defp from_payload(
         %{
           "version" => 1,
           "deviceId" => device_id,
           "secret" => encoded_secret,
           "hostCertificateFingerprint" => fingerprint,
           "pairedRequestId" => request_id,
           "attempts" => attempts
         } = payload,
         device_id
       )
       when map_size(payload) == 6 and is_integer(attempts) and attempts in 0..5 do
    case {fingerprint, request_id, encoded_secret, attempts} do
      {nil, nil, secret, attempt_count} when is_binary(secret) ->
        unpaired_window(device_id, secret, attempt_count)

      {paired_fingerprint, paired_request_id, nil, 0}
      when is_binary(paired_fingerprint) and is_binary(paired_request_id) ->
        if valid_fingerprint?(paired_fingerprint) and valid_request_id?(paired_request_id),
          do: paired_window(device_id, paired_fingerprint, paired_request_id),
          else: {:error, :corrupt_pairing_authority}

      _other ->
        {:error, :corrupt_pairing_authority}
    end
  end

  defp from_payload(_payload, _device_id), do: {:error, :corrupt_pairing_authority}

  defp unpaired_window(device_id, encoded_secret, attempts) do
    with {:ok, secret} <- Base.decode64(encoded_secret),
         true <- Base.encode64(secret) == encoded_secret,
         {:ok, window} <- Window.new(device_id, secret) do
      {:ok, %{window | attempts: attempts}}
    end
  end

  defp paired_window(device_id, fingerprint, request_id) do
    with {:ok, window} <- Window.new(device_id, <<0::128>>) do
      {:ok,
       %{
         window
         | secret: nil,
           host_certificate_fingerprint: fingerprint,
           paired_request_id: request_id
       }}
    end
  end

  defp valid_fingerprint?(value), do: Regex.match?(~r/^sha256:[0-9a-f]{64}$/, value)
  defp valid_request_id?(value), do: Regex.match?(~r/^[A-Za-z0-9._~-]{1,128}$/, value)

  defp write_private_synced(path, bytes) do
    case File.open(path, [:write, :binary, :exclusive]) do
      {:ok, file} ->
        try do
          with :ok <- File.chmod(path, 0o600),
               :ok <- IO.binwrite(file, bytes),
               :ok <- :file.sync(file) do
            :ok
          end
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sync_directory(path) do
    case :file.open(String.to_charlist(path), [:read]) do
      {:ok, directory} ->
        try do
          :file.sync(directory)
        after
          :file.close(directory)
        end

      {:error, :eisdir} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
