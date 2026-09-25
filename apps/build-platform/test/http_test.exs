defmodule FrameshiftPlatformWeb.HTTPTest do
  @moduledoc false

  use FrameshiftPlatform.DataCase, async: false
  import Plug.Conn
  import Phoenix.ConnTest
  @endpoint FrameshiftPlatformWeb.Endpoint

  test "anonymous source reads are bounded and do not accept writes" do
    conn = get(build_conn(), "/api/sources")
    assert %{"data" => [], "more" => false, "offset" => 0} = json_response(conn, 200)

    for offset <- ["-1", "10001", "invalid"] do
      assert %{"error" => "invalid_offset"} =
               build_conn() |> get("/api/sources?offset=#{offset}") |> json_response(400)
    end

    assert build_conn() |> post("/api/sources", %{}) |> response(404)

    for query <- ["offset[]=1", "offset[x]=1", "offset=000001"] do
      assert %{"error" => "invalid_offset"} =
               build_conn() |> get("/api/sources?#{query}") |> json_response(400)
    end
  end

  test "health contains no internal details" do
    assert %{"status" => "ok"} = build_conn() |> get("/api/health") |> json_response(200)
  end

  test "source HTTP projection excludes internal actor attribution" do
    actor = %FrameshiftPlatform.Access.Actor{id: Ecto.UUID.generate(), role: :catalog_editor}

    assert {:ok, _} =
             FrameshiftPlatform.Catalog.record_source(
               %{
                 title: "Public document",
                 uri: "https://example.com/source",
                 revision: "1",
                 content_sha256: String.duplicate("a", 64),
                 kind: :manufacturer,
                 observed_at: DateTime.utc_now()
               },
               actor: actor
             )

    assert %{"data" => [source]} = build_conn() |> get("/api/sources") |> json_response(200)
    assert source["title"] == "Public document"
    refute Map.has_key?(source, "actor_id")
    refute Jason.encode!(source) =~ actor.id
  end

  test "metrics require the configured token and normalize labels" do
    old = Application.get_env(:frameshift_platform, :metrics_token)
    token = String.duplicate("test-metrics-", 4)
    Application.put_env(:frameshift_platform, :metrics_token, token)
    on_exit(fn -> Application.put_env(:frameshift_platform, :metrics_token, old) end)
    assert build_conn() |> get("/ops/metrics") |> response(401)

    :telemetry.execute([:frameshift_platform, :catalog, :source, :stop], %{count: 1}, %{
      outcome: "private-source-id"
    })

    conn =
      build_conn() |> put_req_header("authorization", "Bearer " <> token) |> get("/ops/metrics")

    body = response(conn, 200)
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert body =~ "frameshift_platform_catalog_source_count"
    assert body =~ "other"
    refute body =~ "private-source-id"
  end

  test "production HTML serves exact inline script hashes with frame restrictions" do
    conn = get(build_conn(), "/")
    html = html_response(conn, 200)
    [policy] = get_resp_header(conn, "content-security-policy")
    assert policy =~ "frame-ancestors 'none'"
    refute policy =~ "script-src 'unsafe-inline'"

    for [script] <- Regex.scan(~r/<script\b[^>]*>(.*?)<\/script>/s, html, capture: :all_but_first) do
      digest = Base.encode64(:crypto.hash(:sha256, script))
      assert policy =~ "'sha256-#{digest}'"
    end
  end
end
