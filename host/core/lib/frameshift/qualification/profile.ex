defmodule Frameshift.Qualification.Profile do
  @moduledoc """
  Identifies the byte-affecting part of one admitted frame capability profile.

  Available storage and health are intentionally excluded because they may
  change without changing the bytes a frame accepts or displays.
  """

  alias Frameshift.Digest

  @doc "Returns the canonical digest of one selected artifact profile and its color/geometry contract."
  @spec digest(map(), String.t()) :: {:ok, String.t()} | {:error, :unsupported_profile}
  def digest(capabilities, profile_id)
      when is_map(capabilities) and is_binary(profile_id) do
    with %{
           "storage" => %{"artifactProfiles" => profiles},
           "color" => color,
           "geometry" => geometry
         } <-
           capabilities,
         true <- is_list(profiles) and is_map(color) and is_map(geometry),
         %{} = profile <- Enum.find(profiles, &(&1["id"] == profile_id)),
         {:ok, canonical} <-
           RFC8785.encode(%{
             "artifactProfile" => profile,
             "color" => color,
             "geometry" => geometry
           }) do
      {:ok, Digest.sha256(canonical)}
    else
      _ -> {:error, :unsupported_profile}
    end
  end

  def digest(_, _), do: {:error, :unsupported_profile}

  @doc "Identifies the exact admitted TD and connector revision used for one transfer mode."
  @spec binding_digest(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :invalid_binding}
  def binding_digest(td_json, mode, connector_revision)
      when is_binary(td_json) and mode in ["push", "pull"] and
             is_binary(connector_revision) and byte_size(connector_revision) in 1..128 do
    if String.valid?(connector_revision),
      do: encode_binding(td_json, mode, connector_revision),
      else: {:error, :invalid_binding}
  end

  def binding_digest(_, _, _), do: {:error, :invalid_binding}

  defp encode_binding(td_json, mode, connector_revision) do
    case RFC8785.encode(%{
           "thingDescriptionDigest" => Digest.sha256(td_json),
           "transferMode" => mode,
           "connectorRevision" => connector_revision
         }) do
      {:ok, canonical} -> {:ok, Digest.sha256(canonical)}
      {:error, _} -> {:error, :invalid_binding}
    end
  end
end
