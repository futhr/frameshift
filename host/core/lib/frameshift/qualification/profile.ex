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
end
