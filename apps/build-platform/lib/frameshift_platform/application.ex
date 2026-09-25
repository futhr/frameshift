defmodule FrameshiftPlatform.Application do
  @moduledoc "Supervises the companion platform independently of the computer app."

  use Application

  @impl true
  def start(_, _) do
    children = [
      FrameshiftPlatform.Repo,
      {Phoenix.PubSub, name: FrameshiftPlatform.PubSub},
      {TelemetryMetricsPrometheus.Core,
       name: FrameshiftPlatform.Metrics,
       metrics: FrameshiftPlatform.Telemetry.metrics(),
       start_async: false},
      {:telemetry_poller, measurements: [], period: 10_000}
    ]

    children = children ++ PhoenixAssets.child_specs() ++ [FrameshiftPlatformWeb.Endpoint]
    Supervisor.start_link(children, strategy: :one_for_one, name: FrameshiftPlatform.Supervisor)
  end

  @impl true
  def config_change(changed, _, removed) do
    FrameshiftPlatformWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
