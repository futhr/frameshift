defmodule Frameshift.SimulatorTest do
  use ExUnit.Case, async: true

  alias Frameshift.Digest
  alias Frameshift.Simulator

  @profile_id "urn:frameshift:experimental:test-rgb24-v1"
  @first_bytes <<1, 2, 3, 4, 5, 6>>
  @second_bytes <<6, 5, 4, 3, 2, 1>>

  setup do
    data_dir =
      Path.join(
        System.tmp_dir!(),
        "frameshift-simulator-test-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(data_dir) end)

    capabilities = capabilities()

    {:ok, simulator} =
      Simulator.start_link(data_dir: data_dir, capabilities: capabilities, name: nil)

    on_exit(fn ->
      if Process.alive?(simulator), do: GenServer.stop(simulator)
    end)

    %{simulator: simulator, data_dir: data_dir, capabilities: capabilities}
  end

  test "uploads only verified artifacts that match an advertised profile", %{simulator: simulator} do
    digest = Digest.sha256(@first_bytes)

    assert {:error, :digest_mismatch} =
             Simulator.put_asset(
               simulator,
               "sha256:" <> String.duplicate("0", 64),
               @profile_id,
               @first_bytes
             )

    assert {:error, :unsupported_profile} =
             Simulator.put_asset(simulator, digest, "unknown-profile", @first_bytes)

    assert {:error, :invalid_dimensions} =
             Simulator.put_asset(simulator, Digest.sha256(<<1, 2>>), @profile_id, <<1, 2>>)

    assert {:ok, :created} = Simulator.put_asset(simulator, digest, @profile_id, @first_bytes)
    assert {:ok, :existing} = Simulator.put_asset(simulator, digest, @profile_id, @first_bytes)
    assert Simulator.has_asset?(simulator, digest)
  end

  test "desired activation advances current only after display success", %{simulator: simulator} do
    first = upload!(simulator, @first_bytes)
    second = upload!(simulator, @second_bytes)

    assert {:ok, displayed} = Simulator.set_desired(simulator, desired(first, "request-1"), "*")
    assert displayed["currentAsset"] == first
    assert displayed["previousKnownGood"] == nil
    assert displayed["displayState"] == "displayed"

    %{etag: etag} = Simulator.state(simulator)
    :ok = Simulator.set_faults(simulator, %{display_failure: true})

    assert {:error, :display_failed} =
             Simulator.set_desired(simulator, desired(second, "request-2"), etag)

    %{state: failed} = Simulator.state(simulator)
    assert failed["desiredAsset"] == second
    assert failed["currentAsset"] == first
    assert failed["previousKnownGood"] == nil
    assert failed["displayState"] == "failed"

    :ok = Simulator.set_faults(simulator, %{})
    assert {:ok, retried} = Simulator.retry_display(simulator)
    assert retried["currentAsset"] == second
    assert retried["previousKnownGood"] == first
  end

  test "request IDs are idempotent and conflicting reuse is rejected", %{simulator: simulator} do
    first = upload!(simulator, @first_bytes)
    second = upload!(simulator, @second_bytes)
    request = desired(first, "same-request")

    assert {:ok, first_result} = Simulator.set_desired(simulator, request, "*")
    assert {:ok, repeated_result} = Simulator.set_desired(simulator, request, "stale-etag")
    assert repeated_result == first_result

    assert {:error, :request_id_conflict} =
             Simulator.set_desired(simulator, desired(second, "same-request"), "stale-etag")

    assert {:error, :state_precondition} =
             Simulator.set_desired(simulator, desired(second, "new-request"), "stale-etag")
  end

  test "power loss leaves current intact and restart enters recovery", %{
    simulator: simulator,
    data_dir: data_dir,
    capabilities: capabilities
  } do
    first = upload!(simulator, @first_bytes)
    second = upload!(simulator, @second_bytes)
    {:ok, _state} = Simulator.set_desired(simulator, desired(first, "request-1"), "*")
    %{etag: etag} = Simulator.state(simulator)

    :ok = Simulator.set_faults(simulator, %{power_loss_at: :after_desired})

    assert {:error, :power_loss} =
             Simulator.set_desired(simulator, desired(second, "request-2"), etag)

    GenServer.stop(simulator)

    {:ok, restarted} =
      Simulator.start_link(data_dir: data_dir, capabilities: capabilities, name: nil)

    %{state: recovering} = Simulator.state(restarted)
    assert recovering["displayState"] == "recovering"
    assert recovering["desiredAsset"] == second
    assert recovering["currentAsset"] == first

    assert {:ok, displayed} = Simulator.retry_display(restarted)
    assert displayed["currentAsset"] == second
    assert displayed["previousKnownGood"] == first
    GenServer.stop(restarted)
  end

  test "playlist replacement is atomic, still-only, and capability bounded", %{
    simulator: simulator
  } do
    first = upload!(simulator, @first_bytes)
    second = upload!(simulator, @second_bytes)
    %{etag: etag} = Simulator.state(simulator)

    playlist = playlist([first, second], 1_000)
    assert {:ok, accepted} = Simulator.set_playlist(simulator, playlist, etag)
    assert accepted["playlist"] == playlist

    transition = Map.put(playlist, "transition", "crossfade")
    %{etag: next_etag} = Simulator.state(simulator)
    assert {:error, :invalid_document} = Simulator.set_playlist(simulator, transition, next_etag)

    too_fast = playlist([first], 999)
    assert {:error, :dwell_too_short} = Simulator.set_playlist(simulator, too_fast, next_etag)
    assert Simulator.state(simulator).state["playlist"] == playlist
  end

  test "current, previous, desired, and playlist assets cannot be collected", %{
    simulator: simulator
  } do
    first = upload!(simulator, @first_bytes)
    second = upload!(simulator, @second_bytes)
    {:ok, _state} = Simulator.set_desired(simulator, desired(first, "request-1"), "*")
    %{etag: etag} = Simulator.state(simulator)
    {:ok, _state} = Simulator.set_playlist(simulator, playlist([second], 1_000), etag)

    assert {:error, :asset_referenced} = Simulator.delete_asset(simulator, first)
    assert {:error, :asset_referenced} = Simulator.delete_asset(simulator, second)
  end

  test "unreferenced verified assets can be collected idempotently", %{simulator: simulator} do
    digest = upload!(simulator, @first_bytes)

    assert :ok = Simulator.delete_asset(simulator, digest)
    refute Simulator.has_asset?(simulator, digest)
    assert :ok = Simulator.delete_asset(simulator, digest)
  end

  test "storage-full and corrupt-transfer faults are typed failures", %{simulator: simulator} do
    digest = Digest.sha256(@first_bytes)

    :ok = Simulator.set_faults(simulator, %{storage_full: true})

    assert {:error, :storage_full} =
             Simulator.put_asset(simulator, digest, @profile_id, @first_bytes)

    :ok = Simulator.set_faults(simulator, %{corrupt_upload: true})

    assert {:error, :digest_mismatch} =
             Simulator.put_asset(simulator, digest, @profile_id, @first_bytes)

    assert {:error, :invalid_faults} =
             Simulator.set_faults(simulator, %{display_failure: "yes"})
  end

  test "redundant metadata slots recover the last valid state record", %{
    simulator: simulator,
    data_dir: data_dir,
    capabilities: capabilities
  } do
    first = upload!(simulator, @first_bytes)
    second = upload!(simulator, @second_bytes)
    GenServer.stop(simulator)

    :ok = File.write(Path.join(data_dir, "frame-state-a.json"), "corrupt")

    {:ok, restarted} =
      Simulator.start_link(data_dir: data_dir, capabilities: capabilities, name: nil)

    assert Simulator.has_asset?(restarted, first)
    refute Simulator.has_asset?(restarted, second)
    GenServer.stop(restarted)
  end

  test "unsupported protocol majors cannot start a simulator", %{data_dir: data_dir} do
    incompatible = Map.put(capabilities(), "protocolMajor", 1)

    assert {:error, %JSV.ValidationError{}} =
             Simulator.start_link(
               data_dir: Path.join(data_dir, "incompatible"),
               capabilities: incompatible,
               name: nil
             )
  end

  defp upload!(simulator, bytes) do
    digest = Digest.sha256(bytes)
    assert {:ok, :created} = Simulator.put_asset(simulator, digest, @profile_id, bytes)
    digest
  end

  defp desired(digest, request_id) do
    %{
      "assetDigest" => digest,
      "artifactProfile" => @profile_id,
      "requestId" => request_id
    }
  end

  defp playlist(digests, dwell_ms) do
    entries = Enum.map(digests, &%{"assetDigest" => &1, "dwellMs" => dwell_ms})
    revision = Digest.sha256(RFC8785.encode!(%{"mode" => "cycle", "entries" => entries}))
    %{"revision" => revision, "mode" => "cycle", "entries" => entries}
  end

  defp capabilities do
    %{
      "protocolMajor" => 0,
      "protocolMinor" => 1,
      "deviceId" => "sim-test-0000001",
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
