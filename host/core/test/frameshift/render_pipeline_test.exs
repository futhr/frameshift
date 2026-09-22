defmodule Frameshift.RenderPipelineTest do
  use ExUnit.Case, async: false

  alias Frameshift.Digest
  alias Frameshift.Library
  alias Frameshift.LocalAPI
  alias Frameshift.MasterPackage
  alias Frameshift.Renderer
  alias Frameshift.RenderPipeline
  alias Frameshift.Simulator

  @frame_id "sim-pipeline-0001"
  @profile_id "urn:frameshift:test:rgb24-v1"
  @original <<137, "PNG\r\n", 26, 10, 1, 2, 3>>
  @rgba <<1, 2, 3, 255, 4, 5, 6, 255>>
  @rgb <<1, 2, 3, 4, 5, 6>>
  @renderer_dir Path.expand("../../../../renderer", __DIR__)
  @renderer_path Path.join(@renderer_dir, "zig-out/bin/frameshift-raster")
  @thing_fixture Path.expand(
                   "../../../../protocol/fixtures/valid/thing-description.json",
                   __DIR__
                 )

  setup_all do
    {output, status} =
      System.cmd("zig", ["build", "-Doptimize=ReleaseSafe"],
        cd: @renderer_dir,
        stderr_to_stdout: true
      )

    assert status == 0, output
    :ok
  end

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-pipeline-test-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, library} = Library.start_link(data_dir: Path.join(root, "library"), name: nil)
    {:ok, renderer} = Renderer.start_link(path: @renderer_path, name: nil)

    {:ok, simulator} =
      Simulator.start_link(
        data_dir: Path.join(root, "simulator"),
        capabilities: capabilities(),
        name: nil
      )

    on_exit(fn ->
      Enum.each([library, renderer, simulator], &stop_if_alive/1)
    end)

    %{library: library, renderer: renderer, simulator: simulator}
  end

  test "a queued core command renders, caches, and converges through a universal target",
       context do
    {:ok, package} = MasterPackage.encode(@original, @rgba, 2, 1)
    {:ok, master} = Library.import_master(context.library, package, master_attributes())

    assert {:ok, _frame} =
             Library.register_paired_frame(
               context.library,
               thing_description(),
               "keychain:pipeline-frame",
               "sha256:" <> String.duplicate("d", 64)
             )

    command = %{
      "kind" => "queue",
      "targetID" => @frame_id,
      "itemID" => master["digest"]
    }

    assert {:ok, queued} =
             LocalAPI.execute_with_renderer(context.library, context.renderer, command)

    assert [%{"queuedTargetID" => @frame_id}] = queued["items"]

    assert {:ok, manifest} = Library.outbox_manifest(context.library, @frame_id)
    assert manifest["desiredAsset"] == Digest.sha256(@rgb)
    assert manifest["artifactProfile"] == @profile_id

    assert {:ok, %{"bytes" => @rgb}} =
             Library.read_object(context.library, manifest["desiredAsset"])

    GenServer.stop(context.renderer)

    assert {:ok, _cached_queue} =
             LocalAPI.execute_with_renderer(context.library, context.renderer, command)

    assert {:ok, repeated_manifest} = Library.outbox_manifest(context.library, @frame_id)
    assert repeated_manifest["desiredAsset"] == manifest["desiredAsset"]
    assert repeated_manifest["revision"] == manifest["revision"] + 1

    assert {:ok, acknowledgement} =
             Simulator.pull_outbox(context.simulator, repeated_manifest, @rgb)

    assert acknowledgement["refresh"] == "displayed"
    assert acknowledgement["currentAsset"] == manifest["desiredAsset"]
    assert :ok = Library.acknowledge_outbox(context.library, @frame_id, acknowledgement)
  end

  test "metadata that disagrees with the durable canonical representation is rejected", context do
    {:ok, package} = MasterPackage.encode(@original, @rgba, 2, 1)
    {:ok, master} = Library.import_master(context.library, package, master_attributes())
    mismatched = %{render_job() | source_width: 1}

    assert {:error, :source_dimensions_mismatch} =
             RenderPipeline.render_stored_master(
               context.library,
               context.renderer,
               master["digest"],
               Map.delete(mismatched, :rgba),
               artifact_attributes()
             )
  end

  defp render_job do
    %{
      source_width: 2,
      source_height: 1,
      crop_x: 0,
      crop_y: 0,
      crop_width: 2,
      crop_height: 1,
      target_width: 2,
      target_height: 1,
      background: {0, 0, 0},
      output_format: :rgb24,
      resize_filter: :nearest,
      dither_mode: :none,
      palette: [],
      rgba: @rgba
    }
  end

  defp stop_if_alive(process) do
    if Process.alive?(process), do: GenServer.stop(process)
  catch
    :exit, _reason -> :ok
  end

  defp master_attributes do
    %{
      title: "Canonical RGBA Fixture",
      source_kind: :import,
      width: 2,
      height: 1,
      media_type: MasterPackage.media_type(),
      provenance: %{"kind" => "test-fixture"}
    }
  end

  defp artifact_attributes do
    %{
      profile_id: @profile_id,
      renderer_revision: "frameshift-raster-v0.1",
      media_type: "application/vnd.frameshift.rgb24"
    }
  end

  defp thing_description do
    @thing_fixture
    |> File.read!()
    |> Jason.decode!()
    |> Map.put("id", "urn:frameshift:device:#{@frame_id}")
    |> Map.put("title", "Pipeline Frame")
    |> Map.put("frameshift:capabilities", capabilities())
    |> put_in(
      ["actions", "installAsset", "input", "contentMediaType"],
      artifact_attributes().media_type
    )
    |> put_in(
      ["actions", "installAsset", "forms", Access.at(0), "contentType"],
      artifact_attributes().media_type
    )
    |> put_in(
      ["actions", "installAsset", "forms", Access.at(0), "frameshift:artifactProfile"],
      @profile_id
    )
    |> Jason.encode!()
  end

  defp capabilities do
    %{
      "protocolMajor" => 0,
      "protocolMinor" => 1,
      "deviceId" => @frame_id,
      "hardwareRevision" => "simulator-pipeline-v1",
      "firmwareVersion" => "simulator-0.1.0",
      "stillOnly" => true,
      "transferModes" => ["pull"],
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
