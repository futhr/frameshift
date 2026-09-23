defmodule Frameshift.RenderPipelineTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Frameshift.Digest
  alias Frameshift.Library
  alias Frameshift.LocalAPI
  alias Frameshift.MasterPackage
  alias Frameshift.Qualification.Profile
  alias Frameshift.Renderer
  alias Frameshift.RenderPipeline
  alias Frameshift.Simulator
  alias Frameshift.Transport.CredentialResolver
  alias Frameshift.Transport.KeychainBroker

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

  defmodule StaticCredentialResolver do
    @moduledoc false

    @behaviour CredentialResolver

    @impl CredentialResolver
    def resolve(reference, %{owner: owner}) do
      send(owner, {:credential_reference, reference})
      {:ok, %{certificate: <<1, 2, 3>>, private_key: {:rsa, <<4, 5, 6>>}}}
    end
  end

  defmodule ConfirmedSynchronizer do
    @moduledoc false

    @spec sync(term(), term(), term(), term(), term()) :: {:ok, map()}
    def sync(td, artifact, credential, _, context) do
      send(self(), {:direct_delivery, td, artifact, credential, context})
      {:ok, %{outcome: :displayed}}
    end
  end

  defmodule TimedOutSynchronizer do
    @moduledoc false

    @spec sync(term(), term(), term(), term(), term()) :: {:error, {:transport, :timeout}}
    def sync(_, _, _, _, _),
      do: {:error, {:transport, :timeout}}
  end

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

    assert {:ok, _} =
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

    assert {:ok, _} =
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

  test "qualified render pins active binding, exact build and result across cache replay",
       context do
    {:ok, package} = MasterPackage.encode(@original, @rgba, 2, 1)
    {:ok, master} = Library.import_master(context.library, package, master_attributes())

    {:ok, frame} =
      Library.register_paired_frame(
        context.library,
        thing_description(),
        "keychain:qualified-pipeline-frame",
        "sha256:" <> String.duplicate("d", 64)
      )

    binding = qualification_manifest(frame, Renderer.build_digest(context.renderer))
    {:ok, binding_digest} = Library.register_qualification(context.library, binding)

    :ok =
      Library.admit_qualification(context.library, binding_digest, %{
        "schemaVersion" => 1,
        "scope" => "software_reference",
        "outcome" => "passed",
        "suiteDigest" => Digest.sha256("pipeline qualification fixture")
      })

    :ok = Library.activate_qualification(context.library, @frame_id, binding_digest)
    job = Map.delete(render_job(), :rgba)

    assert {:ok, first} =
             RenderPipeline.render_qualified_stored_master(
               context.library,
               context.renderer,
               @frame_id,
               "pull",
               master["digest"],
               job,
               artifact_attributes()
             )

    assert first["digest"] == Digest.sha256(@rgb)
    assert first.cache == :miss
    assert first.qualification_digest == binding_digest

    assert {:ok, %{"digest" => work_digest}} =
             Library.get_qualified_work(context.library, first.work_digest)

    assert work_digest == first.work_digest

    assert {:ok, %{"artifact_digest" => artifact_digest}} =
             Library.qualified_result(context.library, first.work_digest)

    assert artifact_digest == first["digest"]

    assert {:ok, second} =
             RenderPipeline.render_qualified_stored_master(
               context.library,
               context.renderer,
               @frame_id,
               "pull",
               master["digest"],
               job,
               artifact_attributes()
             )

    assert second.cache == :hit
    assert second.work_digest == first.work_digest
    assert second.result_digest == first.result_digest

    wrong_build = qualification_manifest(frame, Digest.sha256("wrong renderer"))
    {:ok, wrong_digest} = Library.register_qualification(context.library, wrong_build)

    :ok =
      Library.admit_qualification(context.library, wrong_digest, %{
        "schemaVersion" => 1,
        "scope" => "software_reference",
        "outcome" => "passed",
        "suiteDigest" => Digest.sha256("wrong build fixture")
      })

    :ok = Library.activate_qualification(context.library, @frame_id, wrong_digest)

    assert {:error, :qualification_runtime_mismatch} =
             RenderPipeline.render_qualified_stored_master(
               context.library,
               context.renderer,
               @frame_id,
               "pull",
               master["digest"],
               job,
               artifact_attributes()
             )
  end

  test "a push-only queue command renders and records confirmed direct delivery", context do
    {:ok, package} = MasterPackage.encode(@original, @rgba, 2, 1)
    {:ok, master} = Library.import_master(context.library, package, master_attributes())

    push_td =
      thing_description()
      |> Jason.decode!()
      |> put_in(["frameshift:capabilities", "transferModes"], ["push"])
      |> Jason.encode!()

    assert {:ok, _} =
             Library.register_paired_frame(
               context.library,
               push_td,
               "keychain:pipeline-direct-frame",
               "sha256:" <> String.duplicate("d", 64)
             )

    owner = self()

    broker_transport = fn _, request ->
      send(owner, {:keychain_broker_request, request})

      case request["operation"] do
        "resolve" ->
          {:ok,
           %{
             "ok" => true,
             "certificate" => Base.encode64(<<1, 2, 3>>),
             "algorithm" => "ecdsa"
           }}

        "sign" ->
          {:ok, %{"ok" => true, "signature" => Base.encode64(<<4, 5, 6>>)}}
      end
    end

    assert {:ok, snapshot} =
             LocalAPI.execute_with_delivery(
               context.library,
               context.renderer,
               %{
                 "id" => "direct-command-1",
                 "kind" => "queue",
                 "targetID" => @frame_id,
                 "itemID" => master["digest"]
               },
               credential_resolver:
                 {KeychainBroker,
                  %{
                    socket_path: "/unused/credential.sock",
                    token: String.duplicate("a", 64),
                    transport: broker_transport
                  }},
               synchronizer: ConfirmedSynchronizer
             )

    assert snapshot["statusMessage"] == "Displayed on Pipeline Frame"

    assert_receive {:keychain_broker_request,
                    %{
                      "operation" => "resolve",
                      "reference" => "keychain:pipeline-direct-frame"
                    }}

    assert_receive {:direct_delivery, _td, artifact, credential, sync_context}
    assert artifact.bytes == @rgb
    assert artifact.digest == Digest.sha256(@rgb)

    assert credential.server_spki_sha256 ==
             Base.decode16!(String.duplicate("d", 64), case: :lower)

    assert :public_key.sign("tls-proof", :sha256, credential.client_private_key) == <<4, 5, 6>>

    assert_receive {:keychain_broker_request,
                    %{
                      "operation" => "sign",
                      "scheme" => "ecdsa-sha256",
                      "digest" => encoded_digest
                    }}

    assert Base.decode64!(encoded_digest) == :crypto.hash(:sha256, "tls-proof")

    assert sync_context.request_id == "direct-command-1"
    assert :empty = Library.outbox_manifest(context.library, @frame_id)

    assert {:ok, %{"status" => "displayed", "desired_digest" => digest}} =
             Library.direct_delivery(context.library, @frame_id)

    assert digest == artifact.digest
  end

  test "a push timeout reports unknown outcome without discarding the desired asset", context do
    {:ok, package} = MasterPackage.encode(@original, @rgba, 2, 1)
    {:ok, master} = Library.import_master(context.library, package, master_attributes())

    push_td =
      thing_description()
      |> Jason.decode!()
      |> put_in(["frameshift:capabilities", "transferModes"], ["push"])
      |> Jason.encode!()

    assert {:ok, _} =
             Library.register_paired_frame(
               context.library,
               push_td,
               "keychain:pipeline-timeout-frame",
               "sha256:" <> String.duplicate("d", 64)
             )

    assert {:error, :delivery_outcome_unknown} =
             LocalAPI.execute_with_delivery(
               context.library,
               context.renderer,
               %{
                 "id" => "direct-timeout-1",
                 "kind" => "queue",
                 "targetID" => @frame_id,
                 "itemID" => master["digest"]
               },
               credential_resolver: {StaticCredentialResolver, %{owner: self()}},
               synchronizer: TimedOutSynchronizer
             )

    assert {:ok, %{"status" => "pending", "desired_digest" => digest}} =
             Library.direct_delivery(context.library, @frame_id)

    assert digest == Digest.sha256(@rgb)
    assert :empty = Library.outbox_manifest(context.library, @frame_id)
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
    :exit, _ -> :ok
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

  defp qualification_manifest(frame, renderer_digest) do
    connector = "frameshift-outbox-v0.1"
    {:ok, profile_digest} = Profile.digest(frame["capabilities"], @profile_id)
    {:ok, binding_digest} = Profile.binding_digest(frame["td_json"], "pull", connector)

    %{
      "schemaVersion" => 1,
      "frameId" => @frame_id,
      "thingDescriptionDigest" => Digest.sha256(frame["td_json"]),
      "profileId" => @profile_id,
      "profileDigest" => profile_digest,
      "rendererBuildDigest" => renderer_digest,
      "rendererProtocolRevision" => "fsr1",
      "rendererAlgorithmRevision" => "frameshift-raster-v0.1",
      "bindingDigest" => binding_digest,
      "connectorRevision" => connector,
      "effectClass" => "physical_display",
      "transferMode" => "pull"
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
