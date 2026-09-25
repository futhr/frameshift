defmodule FrameshiftPlatform.Catalog.RecordSourceEvent do
  @moduledoc "Commits source attribution atomically and emits bounded telemetry afterward."

  use Ash.Resource.Change
  alias FrameshiftPlatform.Access.AuditEvent

  @impl true
  def change(changeset, _, context) do
    changeset
    |> Ash.Changeset.after_action(fn _, source -> record_event(source, context.actor) end)
    |> Ash.Changeset.after_transaction(&emit_outcome/2)
  end

  defp record_event(source, actor) do
    case Ash.create(AuditEvent, %{event: :source_recorded, subject_id: source.id},
           action: :record,
           actor: actor
         ) do
      {:ok, _} -> {:ok, source}
      {:error, error} -> {:error, error}
    end
  end

  defp emit_outcome(_, result) do
    outcome = if match?({:ok, _}, result), do: :ok, else: :error

    :telemetry.execute([:frameshift_platform, :catalog, :source, :stop], %{count: 1}, %{
      outcome: outcome
    })

    result
  end
end
