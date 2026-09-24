defmodule Frameshift.Pairing.Admission do
  @moduledoc """
  Completes a transient physical pairing exchange before durable frame admission.

  The bootstrap secret is used only in this call. The single writer receives
  the authenticated Thing Description, opaque credential reference, and pin;
  it never receives the bootstrap source or secret.
  """

  alias Frameshift.Library
  alias Frameshift.Pairing.{Bootstrap, Client}
  alias Frameshift.Transport.{HTTPClient, MTLSCredential}
  alias Wotex.Binding.HTTP.{Headers, Request, Response}

  @thing_path "/.well-known/wot"
  @maximum_thing_bytes 262_144
  @timeout_ms 10_000

  @doc "Pairs one discovered device and admits only its authenticated matching TD."
  @spec pair(binary(), String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def pair(bootstrap_source, discovered_id, origin, credential_ref, request_id, options \\ []) do
    resolver = Keyword.get(options, :resolver)
    library = Keyword.get(options, :library, Library)
    pairer = Keyword.get(options, :pairer, &Client.pair/3)
    fetcher = Keyword.get(options, :fetcher, &fetch_thing/2)

    with {:ok, bootstrap} <- Bootstrap.parse(bootstrap_source),
         :ok <- match_discovery(bootstrap, discovered_id),
         :ok <- validate_reference(credential_ref),
         :ok <- require_unpaired(library, bootstrap),
         {:ok, identity} <- resolve_identity(resolver, credential_ref),
         {:ok, credential} <-
           MTLSCredential.new(
             origin,
             bootstrap.server_spki,
             identity.certificate,
             identity.private_key
           ) do
      exchange(bootstrap, credential, credential_ref, request_id, library, pairer, fetcher)
    else
      _ -> {:error, :pairing_preflight_failed}
    end
  end

  defp match_discovery(%Bootstrap{device_id: device_id}, device_id), do: :ok
  defp match_discovery(_, _), do: {:error, :discovery_identity_mismatch}

  defp validate_reference("keychain:" <> encoded) when byte_size(encoded) in 1..1_015,
    do: :ok

  defp validate_reference(_), do: {:error, :invalid_credential_reference}

  defp require_unpaired(library, bootstrap) do
    case {Library.get_paired_frame(library, bootstrap.device_id),
          Library.get_paired_frame_by_spki(library, bootstrap.server_spki)} do
      {:not_found, :not_found} -> :ok
      _ -> {:error, :already_paired}
    end
  end

  defp resolve_identity({module, config}, reference) when is_atom(module) and is_map(config) do
    case module.resolve(reference, config) do
      {:ok, %{certificate: certificate, private_key: private_key}}
      when is_binary(certificate) ->
        {:ok, %{certificate: certificate, private_key: private_key}}

      _ ->
        {:error, :credential_unavailable}
    end
  end

  defp resolve_identity(_, _), do: {:error, :credential_unavailable}

  defp exchange(bootstrap, credential, reference, request_id, library, pairer, fetcher) do
    case pairer.(bootstrap, credential, request_id) do
      {:ok, %{device_id: device_id}} when device_id == bootstrap.device_id ->
        admit_after_pair(bootstrap, credential, reference, library, fetcher)

      {:error, :pairing_rejected} ->
        {:error, :pairing_rejected}

      _ ->
        {:error, :pairing_outcome_unknown}
    end
  end

  defp admit_after_pair(bootstrap, credential, reference, library, fetcher) do
    with {:ok, td_source} <- fetcher.(credential, @thing_path),
         :ok <- Bootstrap.verify_thing_description(bootstrap, td_source),
         {:ok, frame} <-
           Library.register_paired_frame(library, td_source, reference, bootstrap.server_spki) do
      {:ok, %{"frameId" => frame["frame_id"]}}
    else
      _ -> {:error, :pairing_incomplete}
    end
  end

  defp fetch_thing(credential, path) do
    with {:ok, request} <-
           Request.new(
             "GET",
             credential.origin <> path,
             [{"accept", "application/json"}],
             <<>>,
             request_id: "pairing-thing",
             deadline: System.monotonic_time(:millisecond) + @timeout_ms,
             operation: :readproperty,
             media_type: "application/json",
             stream?: false,
             max_response_bytes: @maximum_thing_bytes,
             max_event_bytes: @maximum_thing_bytes,
             max_header_count: 32,
             max_header_bytes: 8_192,
             max_uri_bytes: 1_024
           ),
         {:ok, response} <- HTTPClient.request(request, credential, %{}),
         200 <- Response.status(response),
         "application/json" <- Headers.get(Response.headers(response), "content-type"),
         body when is_binary(body) and byte_size(body) in 1..@maximum_thing_bytes <-
           Response.body(response) do
      {:ok, body}
    else
      _ -> {:error, :thing_unavailable}
    end
  end
end
