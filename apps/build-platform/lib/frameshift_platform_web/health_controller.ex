defmodule FrameshiftPlatformWeb.HealthController do
  @moduledoc "Public liveness without infrastructure or customer details."

  use Phoenix.Controller, formats: [:json]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _), do: json(conn, %{status: "ok"})
end
