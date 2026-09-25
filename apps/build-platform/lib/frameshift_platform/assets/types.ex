defmodule FrameshiftPlatform.Assets.Types do
  @moduledoc "Public Ash projections consumed by the generated frontend contracts."

  use PhoenixAssets.Types.Schema
  type("SourceDocument", resource: FrameshiftPlatform.Catalog.SourceDocument, only: :public)
end
