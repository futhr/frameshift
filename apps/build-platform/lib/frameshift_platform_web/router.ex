defmodule FrameshiftPlatformWeb.Router do
  @moduledoc "Public platform HTTP routes."

  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", FrameshiftPlatformWeb do
    pipe_through :api
    get "/health", HealthController, :show
    get "/sources", SourceController, :index
  end

  get "/ops/metrics", FrameshiftPlatformWeb.MetricsController, :show
  get "/", FrameshiftPlatformWeb.PageController, :show
end
