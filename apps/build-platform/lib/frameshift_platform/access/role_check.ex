defmodule FrameshiftPlatform.Access.RoleCheck do
  @moduledoc "Requires a typed actor with an admitted role and UUID identity."

  use Ash.Policy.SimpleCheck
  alias FrameshiftPlatform.Access.Actor

  @impl true
  def describe(opts), do: "actor has one of #{inspect(opts[:roles])}"

  @impl true
  def match?(actor, _, opts), do: Actor.allowed?(actor, Keyword.fetch!(opts, :roles))
end
