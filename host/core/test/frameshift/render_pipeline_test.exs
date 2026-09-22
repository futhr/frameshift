defmodule Frameshift.RenderPipelineTest do
  use ExUnit.Case, async: false

  alias Frameshift.Digest
  alias Frameshift.Library
  alias Frameshift.Renderer
  alias Frameshift.RenderPipeline
  alias Frameshift.Simulator

  @frame_id "sim-pipeline-0001"
  @profile_id "urn:frameshift:experimental:test-rgb24-v1"
  @rgba <<1, 2, 3, 255, 4, 5, 6, 255>>
  @rgb <<1, 2, 3, 4, 5, 6>>
  @renderer_dir Path.expand("../../../../renderer", __DIR__)
  @renderer_path Path.join(@renderer_dir, "zig-out/bin/frameshift-raster")

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

  test "a canonical master renders, caches, queues, and converges", context do
    {:ok, master} = Library.import_master(context.library, @rgba, master_attributes())

    assert {:ok, artifact} =
             RenderPipeline.render_stored_rgba_master(
               context.library,
               context.renderer,
               master["digest"],
               Map.delete(render_job(), :rgba),
               artifact_attributes()
             )

    assert artifact[:cache] == :miss
    assert artifact["digest"] == Digest.sha256(@rgb)

    GenServer.stop(context.renderer)

    assert {:ok, cached} =
             RenderPipeline.render_stored_rgba_master(
               context.library,
               context.renderer,
               master["digest"],
               Map.delete(render_job(), :rgba),
               artifact_attributes()
             )

    assert cached[:cache] == :hit
    assert cached["digest"] == artifact["digest"]

    {:ok, manifest} =
      Library.queue_outbox(
        context.library,
        @frame_id,
        artifact["digest"],
        @profile_id
      )

    assert {:ok, acknowledgement} =
             Simulator.pull_outbox(context.simulator, manifest, @rgb)

    assert acknowledgement["refresh"] == "displayed"
    assert acknowledgement["currentAsset"] == artifact["digest"]
    assert :ok = Library.acknowledge_outbox(context.library, @frame_id, acknowledgement)
  end

  test "pixels unrelated to the registered master never reach the worker", context do
    {:ok, master} = Library.import_master(context.library, @rgba, master_attributes())
    mismatched = %{render_job() | rgba: <<0, 0, 0, 255, 0, 0, 0, 255>>}

    assert {:error, :source_mismatch} =
             RenderPipeline.render_rgba_master(
               context.library,
               context.renderer,
               master["digest"],
               mismatched,
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
      media_type: "application/vnd.frameshift.experimental.rgba8",
      provenance: %{"kind" => "test-fixture"}
    }
  end

  defp artifact_attributes do
    %{
      profile_id: @profile_id,
      renderer_revision: "frameshift-raster-v0.1",
      media_type: "application/vnd.frameshift.experimental.rgb24"
    }
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
            "mediaType" => "application/vnd.frameshift.experimental.rgb24",
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
