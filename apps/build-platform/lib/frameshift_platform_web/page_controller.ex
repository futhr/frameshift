defmodule FrameshiftPlatformWeb.PageController do
  @moduledoc "Serves the SvelteKit static application with its exact script hashes."

  use Phoenix.Controller, formats: [:html]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _) do
    path = Application.app_dir(:frameshift_platform, "priv/static/index.html")

    case File.read(path) do
      {:ok, html} ->
        serve(conn, html)

      {:error, _} ->
        conn |> put_status(503) |> text("The configuration site is temporarily unavailable.")
    end
  end

  defp serve(conn, html) do
    hashes =
      Regex.scan(~r/<script\b[^>]*>(.*?)<\/script>/s, html, capture: :all_but_first)
      |> Enum.map_join(" ", fn [script] ->
        "'sha256-#{Base.encode64(:crypto.hash(:sha256, script))}'"
      end)

    policy =
      "default-src 'self'; script-src 'self' #{hashes}; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"

    conn
    |> put_resp_header("content-security-policy", policy)
    |> put_resp_header("cache-control", "no-cache")
    |> html(html)
  end
end
