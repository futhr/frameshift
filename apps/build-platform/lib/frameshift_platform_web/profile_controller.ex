defmodule FrameshiftPlatformWeb.ProfileController do
  @moduledoc "Anonymous bounded profile metadata and immutable canonical downloads."

  use Phoenix.Controller, formats: [:json]
  alias FrameshiftPlatform.Catalog
  alias FrameshiftPlatform.Catalog.ProfileRevision
  alias FrameshiftPlatformWeb.CatalogProjection

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    with {:ok, offset} <- CatalogProjection.offset(Map.get(params, "offset", "0")),
         {:ok, page} <-
           Catalog.list_profiles(
             page: [limit: 50, offset: offset],
             query: [sort: [profile_key: :asc, profile_revision: :asc]]
           ) do
      json(conn, %{
        data: Enum.map(page.results, &CatalogProjection.public_record(ProfileRevision, &1)),
        more: page.more?,
        offset: offset
      })
    else
      {:error, :offset} -> conn |> put_status(400) |> json(%{error: "invalid_offset"})
      {:error, _} -> unavailable(conn)
    end
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"digest" => digest}) do
    if is_binary(digest) and Regex.match?(~r/\A[0-9a-f]{64}\z/, digest) do
      load(conn, digest)
    else
      conn |> put_status(400) |> json(%{error: "invalid_digest"})
    end
  end

  defp load(conn, digest) do
    case Catalog.get_profile("sha256:" <> digest, not_found_error?: false) do
      {:ok, nil} -> conn |> put_status(404) |> json(%{error: "profile_not_found"})
      {:ok, profile} -> download(conn, profile)
      {:error, _} -> unavailable(conn)
    end
  end

  defp download(conn, profile) do
    etag = "\"" <> profile.identity <> "\""
    filename = profile.profile_key <> "." <> profile.profile_revision <> ".json"

    conn =
      conn
      |> put_resp_header("etag", etag)
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> put_resp_content_type("application/json")

    if Enum.any?(get_req_header(conn, "if-none-match"), &matches?(&1, etag)),
      do: send_resp(conn, 304, ""),
      else: send_resp(conn, 200, profile.canonical)
  end

  defp matches?(header, etag) when byte_size(header) <= 4_096 do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.any?(&(&1 in ["*", etag, "W/" <> etag]))
  end

  defp matches?(_, _), do: false
  defp unavailable(conn), do: conn |> put_status(503) |> json(%{error: "catalog_unavailable"})
end
