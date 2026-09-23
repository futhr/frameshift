defmodule Frameshift.OutboxTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Digest
  alias Frameshift.Library
  alias Frameshift.Simulator

  @frame_id "sim-test-0000001"
  @profile_id "urn:frameshift:test:rgb24-v1"
  @first_bytes <<1, 2, 3, 4, 5, 6>>
  @second_bytes <<6, 5, 4, 3, 2, 1>>

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-outbox-test-#{System.unique_integer([:positive, :monotonic])}"
      )

    library_dir = Path.join(root, "library")
    simulator_dir = Path.join(root, "simulator")
    on_exit(fn -> File.rm_rf!(root) end)

    {:ok, library} = Library.start_link(data_dir: library_dir, name: nil)

    {:ok, simulator} =
      Simulator.start_link(data_dir: simulator_dir, capabilities: capabilities(), name: nil)

    on_exit(fn ->
      for process <- [library, simulator], Process.alive?(process) do
        try do
          GenServer.stop(process)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    %{library: library, library_dir: library_dir, simulator: simulator}
  end

  test "the newest queued artifact converges through a pull contact", context do
    first = register_artifact!(context.library, @first_bytes)
    second = register_artifact!(context.library, @second_bytes)

    assert {:ok, %{"revision" => 1}} =
             Library.queue_outbox(context.library, @frame_id, first, @profile_id)

    assert {:ok, manifest = %{"revision" => 2, "desiredAsset" => ^second}} =
             Library.queue_outbox(context.library, @frame_id, second, @profile_id)

    assert {:ok, acknowledgement} =
             Simulator.pull_outbox(context.simulator, manifest, @second_bytes)

    assert acknowledgement == %{
             "manifestRevision" => 2,
             "storage" => "verified",
             "refresh" => "displayed",
             "currentAsset" => second,
             "lastError" => nil
           }

    assert :ok = Library.acknowledge_outbox(context.library, @frame_id, acknowledgement)
    assert :empty = Library.outbox_manifest(context.library, @frame_id)

    GenServer.stop(context.library)
    {:ok, restarted} = Library.start_link(data_dir: context.library_dir, name: nil)

    assert {:ok, %{"revision" => 3}} =
             Library.queue_outbox(restarted, @frame_id, first, @profile_id)

    GenServer.stop(restarted)
  end

  test "outbox write failure rolls back its revision and keeps the library alive", context do
    digest = register_artifact!(context.library, @first_bytes)

    {:ok, injector} =
      Exqlite.start_link(database: Path.join(context.library_dir, "metadata.sqlite"))

    Exqlite.query!(
      injector,
      """
      CREATE TRIGGER fail_outbox_insert BEFORE INSERT ON frame_outboxes
      BEGIN SELECT RAISE(ABORT, 'injected outbox failure'); END
      """
    )

    assert {:error, {:database, "injected outbox failure"}} =
             Library.queue_outbox(context.library, @frame_id, digest, @profile_id)

    assert Process.alive?(context.library)
    assert :empty = Library.outbox_manifest(context.library, @frame_id)
    refute Map.has_key?(Library.delivery_custody(context.library, @frame_id), "queued")

    Exqlite.query!(injector, "DROP TRIGGER fail_outbox_insert")
    GenServer.stop(injector)

    assert {:ok, %{"revision" => 1}} =
             Library.queue_outbox(context.library, @frame_id, digest, @profile_id)
  end

  test "a failed refresh stays queued and can be retried on a later contact", context do
    digest = register_artifact!(context.library, @first_bytes)

    {:ok, manifest} =
      Library.queue_outbox(context.library, @frame_id, digest, @profile_id)

    :ok = Simulator.set_faults(context.simulator, %{display_failure: true})
    assert {:ok, failed} = Simulator.pull_outbox(context.simulator, manifest, @first_bytes)
    assert failed["refresh"] == "failed"
    assert failed["currentAsset"] == nil
    assert {:ok, :pending} = Library.acknowledge_outbox(context.library, @frame_id, failed)
    assert {:ok, ^manifest} = Library.outbox_manifest(context.library, @frame_id)

    :ok = Simulator.set_faults(context.simulator, %{})
    assert {:ok, displayed} = Simulator.pull_outbox(context.simulator, manifest, @first_bytes)
    assert displayed["storage"] == "unchanged"
    assert displayed["refresh"] == "displayed"
    assert :ok = Library.acknowledge_outbox(context.library, @frame_id, displayed)
  end

  test "a missed contact and a corrupt transfer leave the queued manifest intact", context do
    digest = register_artifact!(context.library, @first_bytes)

    {:ok, manifest} =
      Library.queue_outbox(context.library, @frame_id, digest, @profile_id)

    :ok = Simulator.set_faults(context.simulator, %{missed_contact: true})

    assert {:error, :contact_missed} =
             Simulator.pull_outbox(context.simulator, manifest, @first_bytes)

    :ok = Simulator.set_faults(context.simulator, %{})
    assert {:error, :digest_mismatch} = Simulator.pull_outbox(context.simulator, manifest, <<0>>)
    assert {:ok, ^manifest} = Library.outbox_manifest(context.library, @frame_id)
    refute Simulator.has_asset?(context.simulator, digest)
  end

  test "stale or contradictory acknowledgements cannot clear the outbox", context do
    digest = register_artifact!(context.library, @first_bytes)

    {:ok, manifest} =
      Library.queue_outbox(context.library, @frame_id, digest, @profile_id)

    acknowledgement = %{
      "manifestRevision" => manifest["revision"] + 1,
      "storage" => "verified",
      "refresh" => "displayed",
      "currentAsset" => digest,
      "lastError" => nil
    }

    assert {:error, :outbox_revision_conflict} =
             Library.acknowledge_outbox(context.library, @frame_id, acknowledgement)

    assert {:error, :current_asset_mismatch} =
             Library.acknowledge_outbox(context.library, @frame_id, %{
               acknowledgement
               | "manifestRevision" => manifest["revision"],
                 "currentAsset" => nil
             })

    assert {:error, :storage_not_verified} =
             Library.acknowledge_outbox(context.library, @frame_id, %{
               acknowledgement
               | "manifestRevision" => manifest["revision"],
                 "storage" => "failed"
             })

    assert {:ok, ^manifest} = Library.outbox_manifest(context.library, @frame_id)
  end

  defp register_artifact!(library, bytes) do
    {:ok, master} = Library.import_master(library, "master-#{Digest.sha256(bytes)}", master())

    {:ok, recipe_hash} =
      Library.register_recipe(
        library,
        :composition,
        %{"height" => 1, "width" => 2},
        [master["digest"]]
      )

    attributes = %{
      master_digest: master["digest"],
      recipe_hash: recipe_hash,
      profile_id: @profile_id,
      renderer_revision: "outbox-test-v1",
      media_type: "application/vnd.frameshift.rgb24"
    }

    {:ok, artifact} = Library.register_artifact(library, bytes, attributes)
    artifact["digest"]
  end

  defp master do
    %{
      title: "Outbox Fixture",
      source_kind: :import,
      width: 2,
      height: 1,
      media_type: "image/png",
      provenance: %{"kind" => "test-fixture"}
    }
  end

  defp capabilities do
    %{
      "protocolMajor" => 0,
      "protocolMinor" => 1,
      "deviceId" => @frame_id,
      "hardwareRevision" => "simulator-test-v1",
      "firmwareVersion" => "simulator-0.1.0",
      "stillOnly" => true,
      "transferModes" => ["push", "pull"],
      "displayClass" => "continuous-color-raster",
      "geometry" => %{
        "width" => 2,
        "height" => 1,
        "orientation" => "identity",
        "safeInset" => %{"top" => 0, "right" => 0, "bottom" => 0, "left" => 0},
        "pixelAspectRatio" => %{"horizontal" => 1, "vertical" => 1}
      },
      "color" => %{
        "kind" => "continuous",
        "colorSpaces" => ["srgb"],
        "transferFunction" => "srgb",
        "channelOrder" => "rgb",
        "bitDepth" => 8,
        "alphaHandling" => "none",
        "profileRevision" => "sim-srgb-v1"
      },
      "refresh" => %{
        "kind" => "sample-and-hold",
        "typicalRefreshMs" => 1,
        "maximumRefreshMs" => 100,
        "minimumDwellMs" => 1_000,
        "flashDuringRefresh" => false
      },
      "power" => %{
        "class" => "continuous-emissive",
        "source" => "external",
        "remoteWake" => true
      },
      "storage" => %{
        "maximumAssetBytes" => 6,
        "totalBytes" => 12,
        "availableBytes" => 12,
        "maximumAssetCount" => 2,
        "digestAlgorithms" => ["sha-256"],
        "artifactProfiles" => [
          %{
            "id" => @profile_id,
            "mediaType" => "application/vnd.frameshift.rgb24",
            "width" => 2,
            "height" => 1,
            "maximumAssetBytes" => 6,
            "rowAlignment" => 1,
            "byteOrder" => "not-applicable",
            "channelOrder" => "rgb",
            "bitDepth" => 8,
            "compression" => "none",
            "colorProfileRevision" => "sim-srgb-v1"
          }
        ],
        "maximumPlaylistLength" => 2
      }
    }
  end
end
