defmodule FrameshiftPlatformWeb.ProfileHTTPTest do
  @moduledoc false

  use FrameshiftPlatform.DataCase, async: false
  import Plug.Conn
  import Phoenix.ConnTest
  alias FrameshiftPlatform.Access.Actor
  alias FrameshiftPlatform.Catalog
  alias FrameshiftPlatform.Catalog.SeedImport
  @endpoint FrameshiftPlatformWeb.Endpoint
  @data Path.expand("../../../data/physical", __DIR__)

  test "bounded anonymous metadata excludes attribution and canonical storage" do
    actor = %Actor{id: Ecto.UUID.generate(), role: :catalog_editor}
    assert {:ok, _} = SeedImport.run(@data, actor)

    assert %{"data" => profiles, "more" => false} =
             build_conn() |> get("/api/profiles") |> json_response(200)

    assert length(profiles) == 3

    for profile <- profiles do
      refute Map.has_key?(profile, "actor_id")
      refute Map.has_key?(profile, "source_bindings")
      refute Map.has_key?(profile, "canonical")
      assert profile["evidence_state"] == "candidate"
    end

    for query <- ["offset=-1", "offset=10001", "offset[]=1", "offset[x]=1"] do
      assert %{"error" => "invalid_offset"} =
               build_conn() |> get("/api/profiles?#{query}") |> json_response(400)
    end

    assert build_conn() |> post("/api/profiles", %{}) |> response(404)
  end

  test "exact downloads use strong ETags and conditional responses without re-encoding" do
    assert {:ok, _} =
             SeedImport.run(@data, %Actor{id: Ecto.UUID.generate(), role: :catalog_editor})

    assert {:ok, %{results: [profile | _]}} = Catalog.list_profiles()
    path = "/api/profiles/" <> String.replace_prefix(profile.identity, "sha256:", "")
    conn = get(build_conn(), path)
    assert response(conn, 200) == profile.canonical
    [etag] = get_resp_header(conn, "etag")
    assert etag == "\"#{profile.identity}\""
    assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    assert [disposition] = get_resp_header(conn, "content-disposition")
    assert disposition =~ profile.profile_key

    for validator <- [etag, "W/" <> etag, "\"other\", " <> etag, "*"] do
      conn = build_conn() |> put_req_header("if-none-match", validator) |> get(path)
      assert response(conn, 304) == ""
      assert get_resp_header(conn, "etag") == [etag]
    end

    assert build_conn()
           |> put_req_header("if-none-match", "\"other\"")
           |> get(path)
           |> response(200) == profile.canonical
  end

  test "invalid and missing digest paths have bounded errors" do
    assert %{"error" => "invalid_digest"} =
             build_conn() |> get("/api/profiles/invalid") |> json_response(400)

    assert %{"error" => "profile_not_found"} =
             build_conn()
             |> get("/api/profiles/#{String.duplicate("0", 64)}")
             |> json_response(404)
  end
end
