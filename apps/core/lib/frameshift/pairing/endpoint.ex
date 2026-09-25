defmodule Frameshift.Pairing.Endpoint do
  @moduledoc """
  Applies one pre-pair HTTPS body to the frame's physical window state.

  The TLS owner supplies the authenticated peer DER certificate; this module
  never accepts certificate bytes from JSON. It returns a bounded response
  and the next state together so the frame can persist successful authorization
  before acknowledging it on the wire.
  """

  alias Frameshift.Pairing.{Request, Window}

  @type response :: %{status: pos_integer(), content_type: String.t(), body: binary()}

  @doc "Builds one pairing response and next state from an authenticated TLS peer."
  @spec handle(Window.t(), binary(), binary(), non_neg_integer()) :: {response(), Window.t()}
  def handle(%Window{} = state, peer_certificate, body, now_ms) do
    with {:ok, request} <- Request.parse(body),
         {:ok, next} <- Request.authorize(state, request, peer_certificate, now_ms) do
      status = if state.host_certificate_fingerprint == nil, do: 201, else: 200

      response =
        success(status, %{
          "version" => 1,
          "requestId" => request.request_id,
          "deviceId" => next.device_id,
          "hostCertificateFingerprint" => next.host_certificate_fingerprint
        })

      {response, next}
    else
      {:error, reason, next} -> {problem(reason), next}
      {:error, reason} -> {problem(reason), state}
    end
  end

  defp success(status, document) do
    %{
      status: status,
      content_type: "application/json",
      body: RFC8785.encode!(document)
    }
  end

  defp problem(reason) do
    {status, code, title} = problem_details(reason)

    %{
      status: status,
      content_type: "application/problem+json",
      body:
        RFC8785.encode!(%{
          "type" => "urn:frameshift:problem:#{code}",
          "title" => title,
          "status" => status
        })
    }
  end

  defp problem_details(:pair_mode_required),
    do: {403, "pair-mode-required", "Physical pair mode is required"}

  defp problem_details(:pairing_locked), do: {429, "pairing-locked", "Pairing window is closed"}
  defp problem_details(:already_paired), do: {409, "already-paired", "Frame is already paired"}
  defp problem_details(:pairing_rejected), do: {403, "pairing-rejected", "Pairing was rejected"}
  defp problem_details(_), do: {400, "invalid-pairing-request", "Invalid pairing request"}
end
