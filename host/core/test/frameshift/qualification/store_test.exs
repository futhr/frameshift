defmodule Frameshift.Qualification.StoreTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Digest
  alias Frameshift.Library
  alias Frameshift.Qualification.Profile

  @fixture Path.expand("../../../../../protocol/fixtures/valid/thing-description.json", __DIR__)
  @fingerprint "sha256:" <> String.duplicate("b", 64)
  @profile_id "urn:frameshift:profile:sim-rgb24-v1"

  setup do
    data_dir =
      Path.join(
        System.tmp_dir!(),
        "frameshift-qualification-test-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(data_dir) end)
    {:ok, library} = Library.start_link(data_dir: data_dir, name: nil)

    {:ok, frame} =
      Library.register_paired_frame(
        library,
        File.read!(@fixture),
        "keychain:fixture",
        @fingerprint
      )

    %{library: library, data_dir: data_dir, frame: frame}
  end

  test "candidate cannot activate and admission is exact and durable", context do
    %{library: library, frame: frame, data_dir: data_dir} = context
    manifest = manifest(frame)
    evidence = evidence()

    assert {:ok, digest} = Library.register_qualification(library, manifest)
    assert {:ok, ^digest} = Library.register_qualification(library, manifest)
    assert :not_found = Library.active_qualification(library, frame["frame_id"])

    assert {:error, :qualification_not_admitted} =
             Library.activate_qualification(library, frame["frame_id"], digest)

    assert {:error, :invalid_qualification_evidence} =
             Library.admit_qualification(library, digest, %{evidence | "outcome" => "failed"})

    assert :ok = Library.admit_qualification(library, digest, evidence)
    assert :ok = Library.admit_qualification(library, digest, evidence)

    assert {:error, :qualification_evidence_conflict} =
             Library.admit_qualification(library, digest, %{
               evidence
               | "suiteDigest" => Digest.sha256("different suite")
             })

    assert :ok = Library.activate_qualification(library, frame["frame_id"], digest)
    assert :ok = Library.activate_qualification(library, frame["frame_id"], digest)

    assert {:ok, %{"digest" => ^digest, "status" => "admitted"}} =
             Library.active_qualification(library, frame["frame_id"])

    assert %{"entries" => audit} = Library.audit_page(library)
    assert Enum.count(audit, &(&1["operation"] == "qualification.candidate")) == 1
    assert Enum.count(audit, &(&1["operation"] == "qualification.admitted")) == 1
    assert Enum.count(audit, &(&1["operation"] == "qualification.activated")) == 1

    GenServer.stop(library)
    {:ok, restarted} = Library.start_link(data_dir: data_dir, name: nil)

    assert {:ok, %{"digest" => ^digest, "manifest" => ^manifest}} =
             Library.active_qualification(restarted, frame["frame_id"])

    GenServer.stop(restarted)
  end

  test "switch and rollback select only future work and retain candidate history", context do
    %{library: library, frame: frame} = context
    first = manifest(frame)
    second = %{first | "rendererBuildDigest" => Digest.sha256("renderer-v2")}

    {:ok, first_digest} = Library.register_qualification(library, first)
    {:ok, second_digest} = Library.register_qualification(library, second)
    assert first_digest != second_digest

    assert :ok = Library.admit_qualification(library, first_digest, evidence())
    assert :ok = Library.admit_qualification(library, second_digest, evidence())
    assert :ok = Library.activate_qualification(library, frame["frame_id"], first_digest)
    assert :ok = Library.activate_qualification(library, frame["frame_id"], second_digest)

    assert {:ok, %{"digest" => ^second_digest}} =
             Library.active_qualification(library, frame["frame_id"])

    assert :ok = Library.activate_qualification(library, frame["frame_id"], first_digest)

    assert {:ok, %{"digest" => ^first_digest}} =
             Library.active_qualification(library, frame["frame_id"])

    assert {:error, :qualification_frame_mismatch} =
             Library.register_qualification(library, %{
               first
               | "profileDigest" => Digest.sha256("mismatched profile")
             })

    assert {:error, :unsupported_qualification_contract} =
             Library.register_qualification(library, %{
               first
               | "connectorRevision" => "unimplemented-connector"
             })

    assert {:error, :qualification_not_admitted} =
             Library.activate_qualification(library, "another-frame", first_digest)

    GenServer.stop(library)
  end

  test "forgetting frame clears active selection and blocks stale reactivation", context do
    %{library: library, frame: frame} = context
    {:ok, digest} = Library.register_qualification(library, manifest(frame))
    :ok = Library.admit_qualification(library, digest, evidence())
    :ok = Library.activate_qualification(library, frame["frame_id"], digest)

    assert :ok = Library.forget_paired_frame(library, frame["frame_id"])
    assert :not_found = Library.active_qualification(library, frame["frame_id"])

    assert {:error, :frame_not_paired} =
             Library.activate_qualification(library, frame["frame_id"], digest)

    GenServer.stop(library)
  end

  test "accepted work and result survive a binding switch and restart", context do
    %{library: library, frame: frame, data_dir: data_dir} = context
    first = manifest(frame)
    {:ok, first_digest} = Library.register_qualification(library, first)
    :ok = Library.admit_qualification(library, first_digest, evidence())
    :ok = Library.activate_qualification(library, frame["frame_id"], first_digest)

    {:ok, master} = Library.import_master(library, "source", master_attributes())
    recipe = composition(first)

    {:ok, recipe_digest} =
      Library.register_recipe(library, :composition, recipe, [master["digest"]])

    assert {:ok, work_digest} =
             Library.accept_qualified_work(
               library,
               frame["frame_id"],
               first_digest,
               master["digest"],
               recipe_digest
             )

    assert {:ok, ^work_digest} =
             Library.accept_qualified_work(
               library,
               frame["frame_id"],
               first_digest,
               master["digest"],
               recipe_digest
             )

    second = %{first | "rendererBuildDigest" => Digest.sha256("renderer-v2")}
    {:ok, second_digest} = Library.register_qualification(library, second)
    :ok = Library.admit_qualification(library, second_digest, evidence())
    :ok = Library.activate_qualification(library, frame["frame_id"], second_digest)

    assert {:error, :qualification_changed} =
             Library.accept_qualified_work(
               library,
               frame["frame_id"],
               first_digest,
               master["digest"],
               recipe_digest
             )

    assert {:ok, artifact} =
             Library.register_artifact(library, "wire bytes", %{
               master_digest: master["digest"],
               recipe_hash: recipe_digest,
               profile_id: @profile_id,
               renderer_revision: first["rendererAlgorithmRevision"],
               media_type: "application/vnd.frameshift.rgb24"
             })

    assert {:ok, result_digest} =
             Library.record_qualified_result(library, work_digest, artifact["digest"])

    assert {:ok, ^result_digest} =
             Library.record_qualified_result(library, work_digest, artifact["digest"])

    assert {:ok, %{"binding_digest" => ^first_digest}} =
             Library.get_qualified_work(library, work_digest)

    assert {:ok, %{"artifact_digest" => artifact_digest}} =
             Library.qualified_result(library, work_digest)

    assert artifact_digest == artifact["digest"]
    GenServer.stop(library)

    {:ok, restarted} = Library.start_link(data_dir: data_dir, name: nil)

    assert {:ok, %{"digest" => ^second_digest}} =
             Library.active_qualification(restarted, frame["frame_id"])

    assert {:ok, %{"binding_digest" => ^first_digest}} =
             Library.get_qualified_work(restarted, work_digest)

    assert {:ok, %{"digest" => ^result_digest}} =
             Library.qualified_result(restarted, work_digest)

    GenServer.stop(restarted)
  end

  test "work refuses mismatched recipe inputs and unknown results", context do
    %{library: library, frame: frame} = context
    binding = manifest(frame)
    {:ok, binding_digest} = Library.register_qualification(library, binding)
    :ok = Library.admit_qualification(library, binding_digest, evidence())
    :ok = Library.activate_qualification(library, frame["frame_id"], binding_digest)
    {:ok, master} = Library.import_master(library, "source", master_attributes())

    mismatched = %{composition(binding) | "rendererBuildDigest" => Digest.sha256("other")}

    {:ok, recipe_digest} =
      Library.register_recipe(library, :composition, mismatched, [master["digest"]])

    assert {:error, :qualification_recipe_mismatch} =
             Library.accept_qualified_work(
               library,
               frame["frame_id"],
               binding_digest,
               master["digest"],
               recipe_digest
             )

    assert {:error, :qualified_work_missing} =
             Library.record_qualified_result(
               library,
               Digest.sha256("missing work"),
               Digest.sha256("a")
             )

    GenServer.stop(library)
  end

  defp manifest(frame) do
    {:ok, profile_digest} = Profile.digest(frame["capabilities"], @profile_id)
    {:ok, binding_digest} = Profile.binding_digest(frame["td_json"], "push", "wotex-http-v0.1")

    %{
      "schemaVersion" => 1,
      "frameId" => frame["frame_id"],
      "thingDescriptionDigest" => Digest.sha256(frame["td_json"]),
      "profileId" => @profile_id,
      "profileDigest" => profile_digest,
      "rendererBuildDigest" => Digest.sha256("renderer-v1"),
      "rendererProtocolRevision" => "fsr1",
      "rendererAlgorithmRevision" => "frameshift-raster-v0.1",
      "bindingDigest" => binding_digest,
      "connectorRevision" => "wotex-http-v0.1",
      "effectClass" => "physical_display",
      "transferMode" => "push"
    }
  end

  defp evidence do
    %{
      "schemaVersion" => 1,
      "scope" => "software_reference",
      "outcome" => "passed",
      "suiteDigest" => Digest.sha256("fixture suite")
    }
  end

  defp composition(binding) do
    %{
      "profileId" => binding["profileId"],
      "rendererRevision" => binding["rendererAlgorithmRevision"],
      "rendererBuildDigest" => binding["rendererBuildDigest"],
      "targetWidth" => 1920,
      "targetHeight" => 1080
    }
  end

  defp master_attributes do
    %{
      title: "Qualification source",
      source_kind: :import,
      width: 1920,
      height: 1080,
      media_type: "image/png",
      provenance: %{"kind" => "test"}
    }
  end
end
