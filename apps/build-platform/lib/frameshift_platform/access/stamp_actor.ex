defmodule FrameshiftPlatform.Access.StampActor do
  @moduledoc "Binds persisted attribution to trusted action context."

  use Ash.Resource.Change
  alias FrameshiftPlatform.Access.Actor

  @impl true
  def change(changeset, _, %{actor: %Actor{id: id}}) do
    Ash.Changeset.force_change_attribute(changeset, :actor_id, id)
  end

  def change(changeset, _, _) do
    Ash.Changeset.add_error(changeset, "authenticated actor required")
  end
end
