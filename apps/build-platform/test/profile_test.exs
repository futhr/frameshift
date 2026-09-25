defmodule FrameshiftPlatform.ProfileTest do
  @moduledoc false

  use FrameshiftPlatform.DataCase, async: true
  alias FrameshiftPlatform.Access.Actor
  alias FrameshiftPlatform.Access.AuditEvent
  alias FrameshiftPlatform.Catalog
  alias FrameshiftPlatform.Catalog.ProfileRevision
  alias FrameshiftPlatform.Catalog.SeedImport

  @fixture File.read!(
             Path.expand("../../../packages/build-spec/test/fixtures/profile-v1.json", __DIR__)
           )
  @data Path.expand("../../../data/physical", __DIR__)

  test "derives immutable identity and exact source bindings with atomic attribution" do
    actor = actor(:catalog_editor)
    source = record_source(actor)

    assert {:ok, profile} =
             Catalog.record_profile(%{label: "Synthetic fixture", canonical: @fixture},
               actor: actor
             )

    assert {:ok, profile.identity} == FrameshiftBuild.profile_identity(@fixture)
    assert profile.profile_key == "fixture-0"
    assert profile.evidence_state == :candidate
    assert profile.actor_id == actor.id
    assert length(profile.source_bindings) == 2
    assert Enum.all?(profile.source_bindings, &(&1["source_document_id"] == source.id))
    assert ["", "dc"] == Enum.map(profile.source_bindings, & &1["port_id"])
    assert {:ok, stored} = Catalog.get_profile(profile.identity)
    assert stored.canonical == @fixture
    assert Enum.any?(events(), &(&1.event == :profile_recorded and &1.subject_id == profile.id))
    assert Ash.Resource.Info.action(ProfileRevision, :update) == nil
    assert Ash.Resource.Info.action(ProfileRevision, :destroy) == nil
  end

  test "missing sources and mismatched evidence kinds cannot admit a profile" do
    actor = actor(:research_worker)

    assert {:error, _} =
             Catalog.record_profile(%{label: "No source", canonical: @fixture}, actor: actor)

    record_source(actor, :manufacturer)

    assert {:error, _} =
             Catalog.record_profile(%{label: "Wrong source class", canonical: @fixture},
               actor: actor
             )

    assert {:ok, %{results: []}} = Catalog.list_profiles()
    refute Enum.any?(events(), &(&1.event == :profile_recorded))
  end

  test "actor policies and derived fields reject caller substitution" do
    actor = actor(:catalog_editor)
    record_source(actor)
    attrs = %{label: "Fixture", canonical: @fixture}

    for caller <- [
          nil,
          actor(:customer),
          actor(:supplier),
          %{id: actor.id, role: :catalog_editor}
        ] do
      assert {:error, _} = Catalog.record_profile(attrs, actor: caller)
    end

    for {key, value} <- [
          identity: "sha256:" <> String.duplicate("0", 64),
          actor_id: Ecto.UUID.generate(),
          evidence_state: :validated,
          source_bindings: []
        ] do
      assert {:error, _} = Catalog.record_profile(Map.put(attrs, key, value), actor: actor)
    end

    assert {:ok, %{results: []}} = Catalog.list_profiles()
  end

  test "revision collisions and late failure never mutate data or retain a profile audit" do
    actor = actor(:catalog_editor)
    record_source(actor)
    attrs = %{label: "Fixture", canonical: @fixture}
    handler = {__MODULE__, self()}
    event = [:frameshift_platform, :catalog, :profile, :stop]
    :ok = :telemetry.attach(handler, event, &__MODULE__.observe/4, self())
    on_exit(fn -> :telemetry.detach(handler) end)

    failed =
      ProfileRevision
      |> Ash.Changeset.for_create(:record, attrs, actor: actor)
      |> Ash.Changeset.after_action(fn _, _ -> {:error, "forced failure"} end)
      |> Ash.create()

    assert {:error, _} = failed
    assert_receive {:profile_outcome, %{count: 1}, %{outcome: :error}}
    assert {:ok, %{results: []}} = Catalog.list_profiles()
    refute Enum.any?(events(), &(&1.event == :profile_recorded))
    assert {:ok, original} = Catalog.record_profile(attrs, actor: actor)
    assert_receive {:profile_outcome, %{count: 1}, %{outcome: :ok}}
    changed = String.replace(@fixture, "\"part_revision\":\"R1\"", "\"part_revision\":\"R2\"")
    assert {:error, _} = Catalog.record_profile(%{attrs | canonical: changed}, actor: actor)
    assert {:ok, %{results: [stored]}} = Catalog.list_profiles()
    assert stored.identity == original.identity
    assert Enum.count(events(), &(&1.event == :profile_recorded)) == 1
  end

  test "canonical bytes are never trimmed, normalized or repaired by the action" do
    actor = actor(:catalog_editor)
    record_source(actor)

    for bytes <- [String.trim_trailing(@fixture), " " <> @fixture, @fixture <> "\n"] do
      assert {:error, _} =
               Catalog.record_profile(%{label: "Invalid bytes", canonical: bytes}, actor: actor)
    end

    assert {:ok, %{results: []}} = Catalog.list_profiles()
  end

  test "source content revision is unique even through a different URI" do
    actor = actor(:catalog_editor)
    record_source(actor)

    assert {:error, _} =
             Catalog.record_source(
               source_attrs(:custom) |> Map.put(:uri, "https://example.com/mirror"),
               actor: actor
             )

    assert {:ok, %{results: [_]}} = Catalog.list_sources()
  end

  test "explicit baseline import is retryable and preserves all three candidates" do
    actor = actor(:catalog_editor)
    assert {:ok, %{sources: 5, profiles: 3}} = SeedImport.run(@data, actor)
    assert {:ok, %{sources: 5, profiles: 3}} = SeedImport.run(@data, actor)
    assert {:ok, %{results: profiles}} = Catalog.list_profiles()
    assert length(profiles) == 3
    assert Enum.all?(profiles, &(&1.evidence_state == :candidate))
    assert length(events()) == 8
    assert {:error, :unauthorized} = SeedImport.run(@data, actor(:customer))
    assert {:error, :unauthorized} = SeedImport.run(@data, nil)
  end

  @tag :tmp_dir
  test "partial imports resume without replacing source leaves or audit events", %{tmp_dir: dir} do
    File.cp_r!(@data, dir)
    manifest = dir |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()
    entry = Enum.at(manifest["profiles"], 1)
    path = Path.join(dir, entry["file"])
    canonical = File.read!(path)
    File.write!(path, canonical <> " ")
    actor = actor(:catalog_editor)

    assert {:error, :invalid_seed_profile} = SeedImport.run(dir, actor)
    assert {:ok, %{results: [_]}} = Catalog.list_profiles()
    assert length(events()) == 6
    File.write!(path, canonical)
    assert {:ok, %{sources: 5, profiles: 3}} = SeedImport.run(dir, actor)
    assert length(events()) == 8

    changed =
      update_in(manifest, ["sources", Access.at(0), "digest"], fn _ ->
        String.duplicate("0", 64)
      end)

    File.write!(Path.join(dir, "manifest.json"), Jason.encode!(changed))
    assert {:error, :source_revision_conflict} = SeedImport.run(dir, actor)
    assert length(events()) == 8
  end

  @tag :tmp_dir
  test "seed files reject oversized input, traversal and direct symlinks", %{tmp_dir: dir} do
    actor = actor(:catalog_editor)
    path = Path.join(dir, "manifest.json")
    File.write!(path, String.duplicate(" ", 262_145))
    assert {:error, :invalid_seed_manifest} = SeedImport.run(dir, actor)
    File.rm!(path)
    File.ln_s!(Path.join(@data, "manifest.json"), path)
    assert {:error, :invalid_seed_manifest} = SeedImport.run(dir, actor)
    File.rm!(path)
    File.cp_r!(@data, dir)
    manifest = path |> File.read!() |> Jason.decode!()
    changed = put_in(manifest, ["profiles", Access.at(0), "file"], "../../elsewhere.json")
    File.write!(path, Jason.encode!(changed))
    assert {:error, :invalid_seed_profile} = SeedImport.run(dir, actor)
    assert {:ok, %{results: []}} = Catalog.list_profiles()
  end

  @spec observe(term(), map(), map(), pid()) :: term()
  def observe(_, measurements, metadata, caller) do
    if self() == caller, do: send(caller, {:profile_outcome, measurements, metadata})
  end

  defp source_attrs(kind) do
    %{
      title: "Synthetic source",
      uri: "https://example.com/fixture",
      revision: "test-1",
      content_sha256: String.duplicate("a", 64),
      kind: kind,
      observed_at: DateTime.utc_now()
    }
  end

  defp record_source(actor, kind \\ :custom),
    do: Catalog.record_source!(source_attrs(kind), actor: actor)

  defp actor(role), do: %Actor{id: Ecto.UUID.generate(), role: role}
  defp events, do: Ash.read!(AuditEvent, actor: actor(:operator))
end
