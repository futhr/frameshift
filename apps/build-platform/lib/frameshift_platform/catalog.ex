defmodule FrameshiftPlatform.Catalog do
  @moduledoc "Sourced component evidence and catalog admission ownership."

  use Ash.Domain

  resources do
    resource FrameshiftPlatform.Catalog.ProfileRevision do
      define :list_profiles, action: :read
      define :record_profile, action: :record
      define :get_profile, action: :by_identity, args: [:identity]
    end

    resource FrameshiftPlatform.Catalog.SourceDocument do
      define :list_sources, action: :read
      define :record_source, action: :record
    end
  end
end
