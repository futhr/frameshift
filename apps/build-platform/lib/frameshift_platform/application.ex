defmodule FrameshiftPlatform.Application do
  @moduledoc "Supervises the companion platform independently of the computer app."

  use Application

  @impl true
  def start(_, _) do
    children = [
      FrameshiftPlatform.Repo,
      {Phoenix.PubSub, name: FrameshiftPlatform.PubSub},
      FrameshiftPlatform.Telemetry.Reporter
    ]

    children =
      children ++
        FrameshiftPlatform.Orchestration.child_specs() ++
        PhoenixAssets.child_specs() ++ [FrameshiftPlatformWeb.Endpoint]

    Supervisor.start_link(children, strategy: :one_for_one, name: FrameshiftPlatform.Supervisor)
  end

  @impl true
  def config_change(changed, _, removed) do
    FrameshiftPlatformWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
