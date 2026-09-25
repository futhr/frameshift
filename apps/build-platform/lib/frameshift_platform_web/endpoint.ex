defmodule FrameshiftPlatformWeb.Endpoint do
  @moduledoc "Bounded HTTP entry point for the companion platform."

  use Phoenix.Endpoint, otp_app: :frameshift_platform

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:frameshift_platform, :endpoint]
  plug Plug.Static, at: "/", from: :frameshift_platform, gzip: true, only: ~w(_app favicon.svg)

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    length: 262_144

  plug Plug.MethodOverride
  plug Plug.Head
  plug FrameshiftPlatformWeb.Router
end
