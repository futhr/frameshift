defmodule FrameshiftPlatformWeb.MetricsController do
  @moduledoc "A token-protected Prometheus scrape, independent of model diagnostics."

  use Phoenix.Controller, formats: [:text]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _) do
    conn = put_resp_header(conn, "cache-control", "no-store")
    token = Application.get_env(:frameshift_platform, :metrics_token)

    if authorized?(get_req_header(conn, "authorization"), token) do
      conn
      |> put_resp_content_type("text/plain", "utf-8")
      |> send_resp(200, TelemetryMetricsPrometheus.Core.scrape(FrameshiftPlatform.Metrics))
    else
      send_resp(conn, 401, "Unauthorized")
    end
  end

  defp authorized?(["Bearer " <> supplied], token)
       when is_binary(token) and byte_size(token) >= 32 do
    Plug.Crypto.secure_compare(:crypto.hash(:sha256, supplied), :crypto.hash(:sha256, token))
  end

  defp authorized?(_, _), do: false
end
