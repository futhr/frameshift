defmodule Frameshift.Outbox.Endpoint do
  @moduledoc """
  Serves a paired frame's pull outbox after mutual-TLS identity verification.

  The HTTPS listener supplies the verified peer certificate in DER form. This
  module derives its SPKI pin and resolves exactly one paired frame; no request
  path, header, or body can select another frame. An asset is served only while
  its digest is the caller's current desired asset;
  old content-addressed objects cannot be fetched merely by knowing a digest.
  This module owns bounded application semantics, not TLS or socket lifetime.
  """

  alias Frameshift.Digest
  alias Frameshift.Library
  alias Frameshift.Protocol.JSON
  alias Frameshift.Transport.SPKIPin

  @type response :: %{
          status: 200 | 204,
          headers: %{String.t() => String.t()},
          body: binary()
        }
  @type reason ::
          :frame_not_paired
          | :ambiguous_frame_identity
          | :invalid_peer_certificate
          | :pull_not_supported
          | :not_found
          | :invalid_request
          | :invalid_acknowledgement
          | :acknowledgement_conflict
          | :artifact_unavailable

  @doc """
  Handles one bounded outbox interaction for a TLS-authenticated frame.

  `content_type` is required for acknowledgements and must be exactly JSON.
  The caller must enforce HTTP framing, a finite read deadline, and mutual TLS
  before passing the DER certificate returned by the TLS socket. A successful
  response includes its exact byte length so the listener cannot accidentally
  use chunked asset transfer.
  """
  @spec handle(GenServer.server(), binary(), String.t(), String.t(), String.t() | nil, binary()) ::
          {:ok, response()} | {:error, reason()}
  def handle(library, peer_certificate_der, method, path, content_type, body)
      when is_binary(peer_certificate_der) and is_binary(method) and is_binary(path) and
             is_binary(body) do
    with {:ok, frame} <- paired_pull_frame(library, peer_certificate_der) do
      route(library, frame, method, path, content_type, body)
    end
  end

  def handle(_, _, _, _, _, _),
    do: {:error, :invalid_request}

  defp route(library, frame, "GET", "/v0/outbox/manifest", _, <<>>) do
    case Library.outbox_manifest(library, frame["frame_id"]) do
      {:ok, manifest} -> json_response(manifest)
      :empty -> {:ok, response(204, nil, <<>>)}
    end
  end

  defp route(library, frame, "GET", "/v0/outbox/assets/sha256/" <> hex, _, <<>>)
       when byte_size(hex) == 64 do
    digest = "sha256:" <> hex

    with true <- Digest.valid_sha256?(digest),
         {:ok, %{"desiredAsset" => ^digest, "artifactProfile" => profile_id}} <-
           Library.outbox_manifest(library, frame["frame_id"]),
         {:ok, ceiling} <- artifact_ceiling(frame, profile_id),
         {:ok, %{"bytes" => bytes}} <- Library.read_object(library, digest, ceiling) do
      headers = %{
        "content-type" => artifact_media_type(frame, profile_id),
        "content-digest" => "sha-256=:#{Base.encode64(:crypto.hash(:sha256, bytes))}:"
      }

      {:ok, response(200, headers, bytes)}
    else
      false -> {:error, :not_found}
      :empty -> {:error, :not_found}
      {:ok, _} -> {:error, :not_found}
      :not_found -> {:error, :artifact_unavailable}
      {:error, :unsupported_profile} -> {:error, :artifact_unavailable}
      {:error, _} -> {:error, :artifact_unavailable}
    end
  end

  defp route(library, frame, "POST", "/v0/outbox/ack", "application/json", body) do
    with {:ok, acknowledgement} <- JSON.decode_control(body, "outbox-ack"),
         {:ok, status} <- acknowledge(library, frame["frame_id"], acknowledgement) do
      json_response(%{"status" => status})
    else
      {:error, :acknowledgement_conflict} = error -> error
      {:error, _} -> {:error, :invalid_acknowledgement}
    end
  end

  defp route(_, _, _, _, _, _),
    do: {:error, :invalid_request}

  defp paired_pull_frame(library, peer_certificate_der) do
    with {:ok, fingerprint} <- SPKIPin.fingerprint_der(peer_certificate_der) do
      paired_pull_frame_by_pin(library, fingerprint)
    else
      {:error, :invalid_certificate} -> {:error, :invalid_peer_certificate}
    end
  end

  defp paired_pull_frame_by_pin(library, fingerprint) do
    case Library.get_paired_frame_by_spki(library, fingerprint) do
      {:ok, %{"capabilities" => %{"transferModes" => modes}} = frame} ->
        if "pull" in modes, do: {:ok, frame}, else: {:error, :pull_not_supported}

      :not_found ->
        {:error, :frame_not_paired}

      {:error, :ambiguous_frame_identity} ->
        {:error, :ambiguous_frame_identity}
    end
  end

  defp artifact_ceiling(frame, profile_id) do
    storage = frame["capabilities"]["storage"]

    case Enum.find(storage["artifactProfiles"], &(&1["id"] == profile_id)) do
      %{"maximumAssetBytes" => profile_limit} ->
        {:ok, min(storage["maximumAssetBytes"], profile_limit)}

      nil ->
        {:error, :unsupported_profile}
    end
  end

  defp artifact_media_type(frame, profile_id) do
    frame["capabilities"]["storage"]["artifactProfiles"]
    |> Enum.find(&(&1["id"] == profile_id))
    |> Map.fetch!("mediaType")
  end

  defp acknowledge(library, frame_id, acknowledgement) do
    case Library.acknowledge_outbox(library, frame_id, acknowledgement) do
      :ok -> {:ok, "confirmed"}
      {:ok, :pending} -> {:ok, "pending"}
      {:error, _} -> {:error, :acknowledgement_conflict}
    end
  end

  defp json_response(document) do
    case JSON.encode(document) do
      {:ok, body} -> {:ok, response(200, %{"content-type" => "application/json"}, body)}
      {:error, _} -> {:error, :invalid_request}
    end
  end

  defp response(status, extra_headers, body) do
    %{
      status: status,
      headers:
        Map.merge(
          %{
            "cache-control" => "no-store",
            "content-length" => Integer.to_string(byte_size(body))
          },
          extra_headers || %{}
        ),
      body: body
    }
  end
end
