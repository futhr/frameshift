defmodule FrameshiftPlatform.Catalog.PrepareProfile do
  @moduledoc "Derives immutable profile metadata solely from the shared validated codec."

  use Ash.Resource.Change

  @derived [:identity, :profile_key, :profile_revision, :kind, :classes]

  @impl true
  def change(changeset, _, _) do
    case FrameshiftBuild.inspect_profile(Ash.Changeset.get_attribute(changeset, :canonical)) do
      {:ok, profile} ->
        changeset
        |> Ash.Changeset.force_change_attributes(Map.take(profile, @derived))
        |> Ash.Changeset.force_change_attribute(:source_bindings, [])
        |> Ash.Changeset.set_context(%{profile_citations: profile.citations})

      {:error, code} ->
        Ash.Changeset.add_error(changeset, field: :canonical, message: code)
    end
  end
end
