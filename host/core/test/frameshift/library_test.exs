defmodule Frameshift.LibraryTest do
  use ExUnit.Case, async: true

  alias Frameshift.ContentStore
  alias Frameshift.Library

  setup do
    data_dir =
      Path.join(
        System.tmp_dir!(),
        "frameshift-library-test-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(data_dir) end)

    {:ok, library} = Library.start_link(data_dir: data_dir, name: nil)
    %{library: library, data_dir: data_dir}
  end

  test "committed masters survive a clean core restart", %{library: library, data_dir: data_dir} do
    {:ok, imported} = Library.import_master(library, "master bytes", master_attributes())

    assert imported[:placement] == :created
    assert File.read!(ContentStore.object_path(data_dir, imported["digest"])) == "master bytes"

    GenServer.stop(library)
    {:ok, restarted} = Library.start_link(data_dir: data_dir, name: nil)

    assert {:ok, persisted} = Library.get_master(restarted, imported["digest"])
    assert persisted["title"] == "Morning Study"
    assert persisted["provenance_json"] == %{"kind" => "local-import"}

    assert {:ok, stored} = Library.read_object(restarted, imported["digest"])
    assert stored["bytes"] == "master bytes"
    assert stored["media_type"] == "image/png"

    GenServer.stop(restarted)
  end

  test "readback is bounded and re-verifies the content address", %{
    library: library,
    data_dir: data_dir
  } do
    {:ok, imported} = Library.import_master(library, "verified bytes", master_attributes())
    digest = imported["digest"]

    assert {:error, :object_too_large} = Library.read_object(library, digest, 4)

    File.write!(ContentStore.object_path(data_dir, digest), "corrupt bytes", [:binary])
    assert {:error, :content_address_mismatch} = Library.read_object(library, digest)
  end

  test "startup repairs an interrupted move to trash without losing active content", %{
    library: library,
    data_dir: data_dir
  } do
    {:ok, imported} = Library.import_master(library, "repair me", master_attributes())
    digest = imported["digest"]
    GenServer.stop(library)

    :ok = ContentStore.move_to_trash(data_dir, digest)
    refute File.exists?(ContentStore.object_path(data_dir, digest))

    {:ok, restarted} = Library.start_link(data_dir: data_dir, name: nil)
    assert File.regular?(ContentStore.object_path(data_dir, digest))
    assert {:ok, %{"digest" => ^digest}} = Library.get_master(restarted, digest)
    GenServer.stop(restarted)
  end

  test "startup refuses metadata that points to missing content", %{
    library: library,
    data_dir: data_dir
  } do
    {:ok, imported} = Library.import_master(library, "missing", master_attributes())
    digest = imported["digest"]
    GenServer.stop(library)

    :ok = File.rm(ContentStore.object_path(data_dir, digest))

    assert {:error, {:object_missing, ^digest}} =
             Library.start_link(data_dir: data_dir, name: nil)
  end

  test "the default data directory uses the operating-system application support location" do
    assert Frameshift.Paths.data_dir() ==
             Path.join([System.user_home!(), "Library", "Application Support", "Frameshift"])
  end

  test "identical master bytes reuse the content-addressed object", %{library: library} do
    assert {:ok, first} = Library.import_master(library, "same bytes", master_attributes())
    assert {:ok, second} = Library.import_master(library, "same bytes", master_attributes())

    assert first["digest"] == second["digest"]
    assert second[:placement] == :existing
  end

  test "canonical recipes ignore map insertion order and preserve source order", %{
    library: library
  } do
    {:ok, source} = Library.import_master(library, "source", master_attributes())

    first = %{"crop" => [0, 0, 10, 10], "profile" => "paper-v1"}
    second = Map.new(Enum.reverse(Map.to_list(first)))

    assert {:ok, first_hash} =
             Library.register_recipe(library, :composition, first, [source["digest"]])

    assert {:ok, second_hash} =
             Library.register_recipe(library, :composition, second, [source["digest"]])

    assert first_hash == second_hash

    assert {:ok, different_hash} =
             Library.register_recipe(library, :composition, first, [])

    refute first_hash == different_hash

    missing_source = "sha256:" <> String.duplicate("f", 64)

    assert {:error, :source_missing} =
             Library.register_recipe(library, :composition, first, [missing_source])
  end

  test "generated variants keep immutable parent and generation recipe relationships", %{
    library: library
  } do
    {:ok, parent} = Library.import_master(library, "parent", master_attributes())

    assert {:ok, recipe_hash} =
             Library.register_recipe(
               library,
               :generation,
               %{"provider" => "fixture", "seed" => 7},
               [parent["digest"]]
             )

    attributes = master_attributes(%{title: "Variant", source_kind: :generated})

    assert {:ok, variant} =
             Library.add_generated_variant(
               library,
               "variant",
               attributes,
               parent["digest"],
               recipe_hash
             )

    assert variant["parent_digest"] == parent["digest"]
    assert variant["generation_recipe_hash"] == recipe_hash

    assert {:error, :parent_or_recipe_missing} =
             Library.add_generated_variant(
               library,
               "orphan",
               attributes,
               "sha256:" <> String.duplicate("0", 64),
               recipe_hash
             )
  end

  test "artifact registration returns a deterministic cache hit", %{library: library} do
    {:ok, master} = Library.import_master(library, "master", master_attributes())

    {:ok, recipe_hash} =
      Library.register_recipe(
        library,
        :composition,
        %{"width" => 2, "height" => 1},
        [master["digest"]]
      )

    attributes = %{
      master_digest: master["digest"],
      recipe_hash: recipe_hash,
      profile_id: "urn:frameshift:test:rgb24",
      renderer_revision: "test-renderer-v1",
      media_type: "application/vnd.frameshift.rgb24"
    }

    assert {:ok, first} = Library.register_artifact(library, <<0, 1, 2, 3, 4, 5>>, attributes)
    assert first[:cache] == :miss

    assert {:ok, second} =
             Library.register_artifact(library, "different ignored bytes", attributes)

    assert second[:cache] == :hit
    assert second["digest"] == first["digest"]
  end

  test "remove is recoverable and collection never deletes protected content", %{
    library: library,
    data_dir: data_dir
  } do
    {:ok, master} = Library.import_master(library, "protected", master_attributes())
    digest = master["digest"]

    assert :ok = Library.pin(library, digest)
    assert :ok = Library.remove_master(library, digest)
    assert {:ok, []} = Library.collect_removed(library)
    assert File.regular?(ContentStore.object_path(data_dir, digest))

    assert :ok = Library.unpin(library, digest)
    assert {:ok, [^digest]} = Library.collect_removed(library)
    refute File.exists?(ContentStore.object_path(data_dir, digest))
    assert File.regular?(ContentStore.trash_path(data_dir, digest))

    assert :ok = Library.restore_master(library, digest)
    assert File.regular?(ContentStore.object_path(data_dir, digest))
    refute File.exists?(ContentStore.trash_path(data_dir, digest))
    assert [%{"digest" => ^digest}] = Library.search(library, "Morning")
  end

  test "recipe and frame references protect removed masters", %{library: library} do
    {:ok, recipe_source} = Library.import_master(library, "recipe source", master_attributes())

    assert {:ok, _recipe_hash} =
             Library.register_recipe(
               library,
               :composition,
               %{"profile" => "fixture"},
               [recipe_source["digest"]]
             )

    :ok = Library.remove_master(library, recipe_source["digest"])
    assert {:ok, []} = Library.collect_removed(library)

    {:ok, frame_source} =
      Library.import_master(library, "frame source", master_attributes(%{title: "Frame Source"}))

    :ok = Library.protect_frame_asset(library, "frame-1", "current", frame_source["digest"])
    :ok = Library.remove_master(library, frame_source["digest"])
    assert {:ok, []} = Library.collect_removed(library)

    :ok = Library.release_frame_asset(library, "frame-1", "current", frame_source["digest"])
    assert {:ok, [digest]} = Library.collect_removed(library)
    assert digest == frame_source["digest"]
  end

  test "search covers titles and labels while user labels remain independent", %{library: library} do
    {:ok, forest} =
      Library.import_master(library, "forest", master_attributes(%{title: "Untitled Study"}))

    :ok = Library.add_label(library, forest["digest"], "forest", :vision, 0.87, "vision-v1")
    :ok = Library.add_label(library, forest["digest"], "quiet", :user)
    :ok = Library.pin(library, forest["digest"])

    assert [%{"digest" => digest, "pinned" => true}] = Library.search(library, "forest")
    assert digest == forest["digest"]
    assert [%{"digest" => ^digest}] = Library.search(library, "quiet", pinned: true)

    assert [] =
             Library.search(library, "quiet", pinned: false, limit: 1)
             |> Enum.reject(& &1["pinned"])
  end

  defp master_attributes(overrides \\ %{}) do
    Map.merge(
      %{
        title: "Morning Study",
        source_kind: :import,
        width: 640,
        height: 480,
        media_type: "image/png",
        provenance: %{"kind" => "local-import"}
      },
      overrides
    )
  end
end
