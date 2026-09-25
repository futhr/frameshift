defmodule FrameshiftPlatform.Access do
  @moduledoc "Actor policy and immutable domain audit ownership."

  use Ash.Domain

  resources do
    resource FrameshiftPlatform.Access.AuditEvent
  end
end
