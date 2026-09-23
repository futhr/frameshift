defmodule Frameshift.Pairing.Bootstrap do
  @moduledoc """
  Admits the physical bootstrap record before any pairing network request.

  The record carries a device identifier, its pinned TLS public-key digest,
  and a one-time secret with at least 128 bits of entropy. It contains no
  network address, binding route, or vendor identifier: discovery supplies a
  candidate endpoint, and the pin must match before the secret is sent.
  """

  @maximum_bytes 2_048
  @device_id_pattern ~r/^[A-Za-z0-9._~-]{16,128}$/
  @spki_pattern ~r/^sha256:[0-9a-f]{64}$/
  @secret_pattern ~r/^[A-Za-z0-9_-]{22,86}$/

  @derive {Inspect, only: [:device_id, :server_spki]}
  @enforce_keys [:device_id, :server_spki, :secret]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          device_id: String.t(),
          server_spki: String.t(),
          secret: binary()
        }

  @doc "Parses a bounded QR/bootstrap record while redacting the secret from inspection."
  @spec parse(binary()) :: {:ok, t()} | {:error, :invalid_bootstrap_record}
  def parse(source) when is_binary(source) and byte_size(source) in 1..@maximum_bytes do
    with {:ok, document} <-
           Wotex.JSON.decode(source,
             max_bytes: @maximum_bytes,
             max_depth: 2,
             max_nodes: 8,
             max_string_bytes: 512,
             max_collection_size: 4
           ),
         %{
           "version" => 1,
           "deviceId" => device_id,
           "serverSpki" => server_spki,
           "secret" => encoded_secret
         } <- document,
         true <- map_size(document) == 4,
         true <- is_binary(device_id) and Regex.match?(@device_id_pattern, device_id),
         true <- is_binary(server_spki) and Regex.match?(@spki_pattern, server_spki),
         true <- is_binary(encoded_secret) and Regex.match?(@secret_pattern, encoded_secret),
         {:ok, secret} <- Base.url_decode64(encoded_secret, padding: false),
         true <- byte_size(secret) in 16..64,
         true <- Base.url_encode64(secret, padding: false) == encoded_secret do
      {:ok, %__MODULE__{device_id: device_id, server_spki: server_spki, secret: secret}}
    else
      _invalid -> {:error, :invalid_bootstrap_record}
    end
  end

  def parse(_source), do: {:error, :invalid_bootstrap_record}

  @doc "Checks the peer certificate against the physical pin before any secret is sent."
  @spec verify_peer(t(), binary()) :: :ok | {:error, :peer_identity_mismatch}
  def verify_peer(%__MODULE__{server_spki: expected}, certificate_der) do
    case Frameshift.Transport.SPKIPin.fingerprint_der(certificate_der) do
      {:ok, ^expected} -> :ok
      _other -> {:error, :peer_identity_mismatch}
    end
  end

  @doc "Checks that the authenticated TD belongs to the physical device ID."
  @spec verify_thing_description(t(), binary()) ::
          :ok | {:error, :device_identity_mismatch}
  def verify_thing_description(%__MODULE__{device_id: expected}, td_source) do
    with {:ok, td} <- Frameshift.Protocol.Thing.parse_frame(td_source),
         %{"frameshift:capabilities" => %{"deviceId" => ^expected}} <-
           Wotex.ThingDescription.to_map(td) do
      :ok
    else
      _other -> {:error, :device_identity_mismatch}
    end
  end
end
