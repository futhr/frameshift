defmodule FrameshiftPlatform.CatalogTest do
  @moduledoc false

  use FrameshiftPlatform.DataCase, async: true
  alias FrameshiftPlatform.Access.Actor
  alias FrameshiftPlatform.Access.AuditEvent
  alias FrameshiftPlatform.Catalog
  alias FrameshiftPlatform.Catalog.SourceDocument

  test "records exact immutable metadata and an actor-bound audit fact" do
    actor = actor(:catalog_editor)
    assert {:ok, source} = Catalog.record_source(source(), actor: actor)
    assert source.actor_id == actor.id
    assert {:ok, page} = Catalog.list_sources()
    assert [stored] = page.results
    assert stored.content_sha256 == source.content_sha256
    assert [event] = Ash.read!(AuditEvent, actor: actor(:operator))
    assert event.actor_id == actor.id
    assert event.subject_id == source.id
    assert event.event == :source_recorded
    assert Ash.Resource.Info.action(SourceDocument, :update) == nil
    assert Ash.Resource.Info.action(SourceDocument, :destroy) == nil
  end

  test "allows the typed research worker and denies customers, suppliers and untyped actors" do
    assert {:ok, _} = Catalog.record_source(source(), actor: actor(:research_worker))

    for caller <- [
          nil,
          actor(:customer),
          actor(:supplier),
          %{id: Ecto.UUID.generate(), role: :catalog_editor}
        ] do
      assert {:error, _} = Catalog.record_source(source(%{revision: "other"}), actor: caller)
      assert {:error, _} = Ash.read(AuditEvent, actor: caller)
    end

    assert {:ok, %{results: [_]}} = Catalog.list_sources()
  end

  test "same source revision cannot replace its digest" do
    actor = actor(:catalog_editor)
    assert {:ok, first} = Catalog.record_source(source(), actor: actor)

    assert {:error, _} =
             Catalog.record_source(source(%{content_sha256: String.duplicate("b", 64)}),
               actor: actor
             )

    assert {:ok, %{results: [stored]}} = Catalog.list_sources()
    assert stored.id == first.id
    assert stored.content_sha256 == first.content_sha256
    assert [_] = Ash.read!(AuditEvent, actor: actor(:operator))
  end

  test "rejects credentials, fragments, unsupported schemes and invalid digests" do
    for uri <- [
          "http://example.com/manual",
          "https://user:secret@example.com/manual",
          "https://example.com/manual#x",
          "file:///tmp/manual"
        ] do
      assert {:error, _} =
               Catalog.record_source(source(%{uri: uri}), actor: actor(:catalog_editor))
    end

    assert {:error, _} =
             Catalog.record_source(source(%{content_sha256: "invalid"}),
               actor: actor(:catalog_editor)
             )

    assert {:ok, %{results: []}} = Catalog.list_sources()
    assert [] == Ash.read!(AuditEvent, actor: actor(:operator))
  end

  test "private actor attribution is never part of the generated public type" do
    fields = Ash.Resource.Info.public_attributes(SourceDocument) |> Enum.map(& &1.name)
    refute :actor_id in fields
    assert :content_sha256 in fields
  end

  test "a failed post-write action rolls back both the source and its audit event" do
    result =
      SourceDocument
      |> Ash.Changeset.for_create(:record, source(), actor: actor(:catalog_editor))
      |> Ash.Changeset.after_action(fn _, _ -> {:error, "forced transaction failure"} end)
      |> Ash.create()

    assert {:error, _} = result
    assert {:ok, %{results: []}} = Catalog.list_sources()
    assert [] == Ash.read!(AuditEvent, actor: actor(:operator))
  end

  defp actor(role), do: %Actor{id: Ecto.UUID.generate(), role: role}

  defp source(overrides \\ %{}) do
    Map.merge(
      %{
        title: "Manufacturer manual",
        uri: "https://example.com/manual",
        revision: "P1",
        content_sha256: String.duplicate("a", 64),
        kind: :manufacturer,
        observed_at: DateTime.utc_now()
      },
      overrides
    )
  end
end
