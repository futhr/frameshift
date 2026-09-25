defmodule FrameshiftPlatform.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  setup tags do
    owner =
      Ecto.Adapters.SQL.Sandbox.start_owner!(FrameshiftPlatform.Repo, shared: not tags[:async])

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)
    :ok
  end
end
