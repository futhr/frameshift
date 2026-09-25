defmodule Frameshift.Playlist.Plan do
  @moduledoc """
  Builds a complete still playlist from an ordered, already rendered artifact set.

  The host prepares immutable artifacts before asking a receiver to install the
  plan. This pure boundary never treats a library pin as an active playlist.
  """

  alias Frameshift.Digest
  alias Frameshift.DisplayTiming

  @type plan :: %{
          playlist: map(),
          dwell_ms: pos_integer(),
          source: :profile | :override,
          recommendation_revision: String.t() | nil
        }

  @doc "Constructs one canonical cycle, requiring an explicit dwell without a profile suggestion."
  @spec build(map(), [String.t()], pos_integer() | nil) :: {:ok, plan()} | {:error, atom()}
  def build(capabilities, artifact_digests, requested_dwell \\ nil) do
    with :ok <- validate_artifacts(capabilities, artifact_digests),
         {:ok, dwell, source, revision} <- resolve_dwell(capabilities, requested_dwell) do
      entries =
        Enum.map(artifact_digests, &%{"assetDigest" => &1, "dwellMs" => dwell})

      payload = %{"mode" => "cycle", "entries" => entries}
      playlist = Map.put(payload, "revision", Digest.sha256(RFC8785.encode!(payload)))

      {:ok,
       %{
         playlist: playlist,
         dwell_ms: dwell,
         source: source,
         recommendation_revision: revision
       }}
    end
  end

  defp validate_artifacts(%{"storage" => %{"maximumPlaylistLength" => maximum}}, digests)
       when is_list(digests) do
    cond do
      digests == [] -> {:error, :empty_playlist}
      length(digests) > maximum -> {:error, :playlist_too_long}
      length(Enum.uniq(digests)) != length(digests) -> {:error, :duplicate_artifact}
      not Enum.all?(digests, &Digest.valid_sha256?/1) -> {:error, :invalid_artifact}
      true -> :ok
    end
  end

  defp validate_artifacts(_, _), do: {:error, :invalid_artifact}

  @doc "Resolves an operator interval or the profile suggestion before rendering."
  @spec resolve_dwell(map(), pos_integer() | nil) ::
          {:ok, pos_integer(), :profile | :override, String.t() | nil} | {:error, atom()}
  def resolve_dwell(capabilities, nil) do
    case DisplayTiming.recommendation(capabilities) do
      nil -> {:error, :interval_required}
      %{dwell_ms: dwell, revision: revision} -> {:ok, dwell, :profile, revision}
    end
  end

  def resolve_dwell(capabilities, dwell) when is_integer(dwell) and dwell > 0 do
    clamped = DisplayTiming.clamp_dwell(capabilities, dwell)
    {:ok, clamped, :override, nil}
  end

  def resolve_dwell(_, _), do: {:error, :invalid_interval}
end
