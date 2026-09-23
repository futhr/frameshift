defmodule Frameshift.Transport.MTLSCredential do
  @moduledoc """
  Ephemeral mutual-TLS material for one admitted frame authority.

  The value is resolved immediately before a transport call. Its custom
  inspection deliberately omits the client certificate and private key so an
  exception or diagnostic cannot serialize credential material by accident.
  """

  @fingerprint_pattern ~r/^sha256:([0-9a-f]{64})$/
  @maximum_certificate_bytes 65_536

  @enforce_keys [
    :origin,
    :host,
    :port,
    :server_spki_sha256,
    :client_certificate,
    :client_private_key
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          origin: String.t(),
          host: String.t(),
          port: :inet.port_number(),
          server_spki_sha256: binary(),
          client_certificate: binary(),
          client_private_key: term()
        }

  @spec new(String.t(), String.t(), binary(), term()) :: {:ok, t()} | {:error, atom()}
  def new(origin, fingerprint, certificate, private_key)
      when is_binary(origin) and is_binary(fingerprint) and is_binary(certificate) do
    with {:ok, host, port, normalized_origin} <- parse_origin(origin),
         {:ok, pin} <- parse_fingerprint(fingerprint),
         :ok <- validate_certificate(certificate),
         :ok <- validate_private_key(private_key) do
      {:ok,
       %__MODULE__{
         origin: normalized_origin,
         host: host,
         port: port,
         server_spki_sha256: pin,
         client_certificate: certificate,
         client_private_key: private_key
       }}
    end
  end

  def new(_, _, _, _),
    do: {:error, :invalid_mtls_credential}

  defp parse_origin(origin) do
    with {:ok, uri} <- URI.new(origin),
         true <- uri.scheme == "https",
         true <- is_binary(uri.host) and uri.host != "",
         true <- is_nil(uri.userinfo) and is_nil(uri.query) and is_nil(uri.fragment),
         true <- uri.path in [nil, "", "/"],
         port when port in 1..65_535 <- uri.port || 443 do
      host = String.downcase(uri.host)
      authority = if port == 443, do: host, else: "#{host}:#{port}"
      {:ok, host, port, "https://#{authority}"}
    else
      _ -> {:error, :invalid_credential_origin}
    end
  end

  defp parse_fingerprint(fingerprint) do
    case Regex.run(@fingerprint_pattern, fingerprint, capture: :all_but_first) do
      [hex] ->
        case Base.decode16(hex, case: :lower) do
          {:ok, pin} -> {:ok, pin}
          :error -> {:error, :invalid_server_fingerprint}
        end

      _ ->
        {:error, :invalid_server_fingerprint}
    end
  end

  defp validate_certificate(certificate)
       when byte_size(certificate) in 1..@maximum_certificate_bytes,
       do: :ok

  defp validate_certificate(_), do: {:error, :invalid_client_certificate}

  defp validate_private_key({_, _}), do: :ok

  defp validate_private_key(%{algorithm: _, sign_fun: sign_fun})
       when is_function(sign_fun, 3),
       do: :ok

  defp validate_private_key(%{algorithm: _, engine: _, key_id: _}), do: :ok
  defp validate_private_key(_), do: {:error, :invalid_client_private_key}
end

defimpl Inspect, for: Frameshift.Transport.MTLSCredential do
  @moduledoc """
  Redacts mutual-TLS key material from credential inspection.

  Diagnostic formatting includes the origin and server pin only; certificate
  and private-key values never enter ordinary logs through `inspect/2`.
  """

  import Inspect.Algebra

  @spec inspect(Frameshift.Transport.MTLSCredential.t(), Inspect.Opts.t()) :: Inspect.Algebra.t()
  def inspect(credential, opts) do
    concat([
      "#Frameshift.Transport.MTLSCredential<origin=",
      to_doc(credential.origin, opts),
      " server_spki_sha256=",
      to_doc(Base.encode16(credential.server_spki_sha256, case: :lower), opts),
      " credentials=redacted>"
    ])
  end
end
