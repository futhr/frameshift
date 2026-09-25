defmodule FrameshiftPlatform.Access.AuditEvent do
  @moduledoc "Append-only domain facts written inside the originating transaction."

  use Ash.Resource,
    domain: FrameshiftPlatform.Access,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "platform_audit_events"
    repo FrameshiftPlatform.Repo
  end

  actions do
    defaults [:read]

    create :record do
      accept [:event, :subject_id]
      change FrameshiftPlatform.Access.StampActor
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if {FrameshiftPlatform.Access.RoleCheck, roles: [:operator]}
    end

    policy action(:record) do
      authorize_if {FrameshiftPlatform.Access.RoleCheck,
                    roles: [:catalog_editor, :research_worker]}
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :actor_id, :uuid, allow_nil?: false, writable?: false, sensitive?: true
    attribute :subject_id, :uuid, allow_nil?: false
    attribute :event, :atom, allow_nil?: false, constraints: [one_of: [:source_recorded]]
    create_timestamp :recorded_at
  end
end
