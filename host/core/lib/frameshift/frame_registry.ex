defmodule Frameshift.FrameRegistry do
  @moduledoc """
  Admission boundary for durable paired-frame records.

  A record is derived from a bounded Frameshift/W3C Thing Description and
  explicit pairing outputs. The credential reference is opaque metadata (for
  example a Keychain persistent reference); private key material never enters
  this boundary.
  """

  alias Frameshift.Protocol.Thing
  alias Wotex.ThingDescription

  @fingerprint_pattern ~r/^sha256:[0-9a-f]{64}$/

  @type paired_frame :: %{
          frame_id: String.t(),
          thing_id: String.t(),
          title: String.t(),
          medium: String.t(),
          td_json: String.t(),
          capabilities_json: String.t(),
          credential_ref: String.t(),
          server_spki_fingerprint: String.t()
        }

  @spec admit(binary(), String.t(), String.t()) :: {:ok, paired_frame()} | {:error, term()}
  def admit(td_source, credential_ref, server_spki_fingerprint)
      when is_binary(td_source) and is_binary(credential_ref) and
             is_binary(server_spki_fingerprint) do
    with :ok <- validate_credential_ref(credential_ref),
         :ok <- validate_fingerprint(server_spki_fingerprint),
         {:ok, td} <- Thing.parse_frame(td_source),
         document = ThingDescription.to_map(td),
         {:ok, capabilities} <- fetch_capabilities(document),
         {:ok, medium} <- medium(capabilities["displayClass"]),
         {:ok, td_json} <- RFC8785.encode(document),
         {:ok, capabilities_json} <- RFC8785.encode(capabilities) do
      {:ok,
       %{
         frame_id: capabilities["deviceId"],
         thing_id: document["id"],
         title: document["title"],
         medium: medium,
         td_json: td_json,
         capabilities_json: capabilities_json,
         credential_ref: credential_ref,
         server_spki_fingerprint: server_spki_fingerprint
       }}
    end
  end

  def admit(_td_source, _credential_ref, _server_spki_fingerprint),
    do: {:error, :invalid_pairing_record}

  defp validate_credential_ref(reference) when byte_size(reference) in 1..512, do: :ok
  defp validate_credential_ref(_reference), do: {:error, :invalid_credential_reference}

  defp validate_fingerprint(fingerprint) do
    if Regex.match?(@fingerprint_pattern, fingerprint),
      do: :ok,
      else: {:error, :invalid_server_fingerprint}
  end

  defp fetch_capabilities(%{"frameshift:capabilities" => capabilities})
       when is_map(capabilities),
       do: {:ok, capabilities}

  defp fetch_capabilities(_document), do: {:error, :capabilities_missing}

  defp medium("restricted-palette-reflective"), do: {:ok, "paper"}
  defp medium("continuous-color-raster"), do: {:ok, "photo"}
  defp medium("low-resolution-emissive-matrix"), do: {:ok, "pixel"}
  defp medium(_display_class), do: {:error, :unsupported_display_class}
end
