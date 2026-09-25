defmodule FrameshiftPlatform.Catalog do
  @moduledoc "Sourced component evidence and catalog admission ownership."

  use Ash.Domain

  resources do
    resource FrameshiftPlatform.Catalog.SourceDocument do
      define :list_sources, action: :read
      define :record_source, action: :record
    end
  end
end
