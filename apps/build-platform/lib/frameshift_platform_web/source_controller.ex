defmodule FrameshiftPlatformWeb.SourceController do
  @moduledoc "Bounded anonymous reads of public catalog-source metadata."

  use Phoenix.Controller, formats: [:json]
  alias FrameshiftPlatform.Catalog
  alias FrameshiftPlatform.Catalog.SourceDocument
  alias FrameshiftPlatformWeb.CatalogProjection

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    with {:ok, offset} <- CatalogProjection.offset(Map.get(params, "offset", "0")),
         {:ok, page} <-
           Catalog.list_sources(
             page: [limit: 50, offset: offset],
             query: [sort: [recorded_at: :desc, id: :asc]]
           ) do
      json(conn, %{
        data: Enum.map(page.results, &CatalogProjection.public_record(SourceDocument, &1)),
        more: page.more?,
        offset: offset
      })
    else
      {:error, :offset} -> conn |> put_status(400) |> json(%{error: "invalid_offset"})
      {:error, _} -> conn |> put_status(503) |> json(%{error: "catalog_unavailable"})
    end
  end
end
