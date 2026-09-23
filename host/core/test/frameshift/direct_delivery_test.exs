defmodule Frameshift.DirectDeliveryTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Digest
  alias Frameshift.DirectDelivery
  alias Frameshift.Library
  alias Frameshift.LocalAPI
  alias Frameshift.Transport.CredentialResolver

  @frame_id "sim-photo-00000001"
  @profile_id "urn:frameshift:profile:sim-rgb24-v1"
  @frame_fixture Path.expand(
                   "../../../../protocol/fixtures/valid/thing-description.json",
                   __DIR__
                 )

  defmodule StaticCredentialResolver do
    @moduledoc false

    @behaviour CredentialResolver

    @impl CredentialResolver
    def resolve(_, _) do
      {:ok, %{certificate: <<1, 2, 3>>, private_key: {:rsa, <<4, 5, 6>>}}}
    end
  end

  defmodule TimedOutSynchronizer do
    @moduledoc false

    @spec sync(term(), term(), term(), term(), term()) :: {:error, :timeout}
    def sync(_, _, _, _, _), do: {:error, :timeout}
  end

  defmodule ConfirmingSynchronizer do
    @moduledoc false

    @spec observe(term(), term(), term(), term(), term(), term()) :: {:ok, :displayed}
    def observe(_, _, _, _, _, _),
      do: {:ok, :displayed}
  end

  defmodule PendingSynchronizer do
    @moduledoc false

    @spec observe(term(), term(), term(), term(), term(), term()) :: {:ok, :not_applied}
    def observe(_, _, _, _, _, _),
      do: {:ok, :not_applied}
  end

  setup do
    data_dir =
      Path.join(
        System.tmp_dir!(),
        "frameshift-direct-delivery-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(data_dir) end)
    {:ok, library} = Library.start_link(data_dir: data_dir, name: nil)
    on_exit(fn -> if Process.alive?(library), do: GenServer.stop(library) end)

    assert {:ok, _} =
             Library.register_paired_frame(
               library,
               File.read!(@frame_fixture),
               "keychain:direct-delivery-test",
               "sha256:" <> String.duplicate("a", 64)
             )

    %{data_dir: data_dir, library: library}
  end

  test "an unknown push outcome survives restart and only confirmed display advances current",
       context do
    first = register_artifact!(context.library, <<1, 2, 3, 4, 5, 6>>)

    assert {:ok, first_intent = %{"revision" => 1, "status" => "pending"}} =
             Library.begin_direct_delivery(
               context.library,
               @frame_id,
               first,
               @profile_id,
               "push-1"
             )

    assert %{
             "targets" => [
               %{
                 "directDelivery" => %{
                   "status" => "pending",
                   "revision" => 1,
                   "desiredDigest" => ^first
                 }
               }
             ]
           } = LocalAPI.snapshot(context.library)

    assert {:ok, ^first_intent} =
             Library.begin_direct_delivery(
               context.library,
               @frame_id,
               first,
               @profile_id,
               "push-1"
             )

    assert {:ok, :pending} =
             Library.finish_direct_delivery(
               context.library,
               @frame_id,
               1,
               "push-1",
               first,
               :pending
             )

    assert [{"desired", ^first}] = references(context.data_dir)

    GenServer.stop(context.library)
    {:ok, restarted} = Library.start_link(data_dir: context.data_dir, name: nil)
    on_exit(fn -> if Process.alive?(restarted), do: GenServer.stop(restarted) end)

    assert {:ok, %{"revision" => 1, "status" => "pending"}} =
             Library.direct_delivery(restarted, @frame_id)

    assert {:error, :direct_delivery_conflict} =
             Library.finish_direct_delivery(restarted, @frame_id, 2, "push-1", first, :displayed)

    assert [{"desired", ^first}] = references(context.data_dir)

    assert :ok =
             Library.finish_direct_delivery(restarted, @frame_id, 1, "push-1", first, :displayed)

    assert %{"targets" => [%{"directDelivery" => %{"status" => "displayed"}}]} =
             LocalAPI.snapshot(restarted)

    assert :ok =
             Library.finish_direct_delivery(restarted, @frame_id, 1, "push-1", first, :displayed)

    assert [{"current", ^first}] = references(context.data_dir)

    assert {:ok, %{"connection_state" => "displayed"}} =
             Library.get_paired_frame(restarted, @frame_id)

    second = register_artifact!(restarted, <<6, 5, 4, 3, 2, 1>>)

    assert {:ok, %{"revision" => 2, "status" => "pending"}} =
             Library.begin_direct_delivery(restarted, @frame_id, second, @profile_id, "push-2")

    assert [{"current", ^first}, {"desired", ^second}] = references(context.data_dir)

    assert :ok =
             Library.finish_direct_delivery(restarted, @frame_id, 2, "push-2", second, :displayed)

    assert [{"current", ^second}, {"previous-known-good", ^first}] =
             references(context.data_dir)
  end

  test "invalid or conflicting direct intents never change durable state", context do
    first = register_artifact!(context.library, <<1, 2, 3, 4, 5, 6>>)
    second = register_artifact!(context.library, <<6, 5, 4, 3, 2, 1>>)

    assert {:error, :invalid_direct_delivery} =
             Library.begin_direct_delivery(context.library, @frame_id, first, @profile_id, "")

    assert {:error, :artifact_missing} =
             Library.begin_direct_delivery(
               context.library,
               @frame_id,
               Digest.sha256("missing"),
               @profile_id,
               "missing-request"
             )

    assert {:error, :unsupported_profile} =
             Library.begin_direct_delivery(
               context.library,
               @frame_id,
               first,
               "wrong-profile",
               "wrong"
             )

    assert {:ok, %{"revision" => 1}} =
             Library.begin_direct_delivery(
               context.library,
               @frame_id,
               first,
               @profile_id,
               "shared"
             )

    assert {:error, :request_id_conflict} =
             Library.begin_direct_delivery(
               context.library,
               @frame_id,
               second,
               @profile_id,
               "shared"
             )

    assert {:error, :direct_delivery_pending} =
             Library.begin_direct_delivery(
               context.library,
               @frame_id,
               second,
               @profile_id,
               "next-request"
             )

    assert [{"desired", ^first}] = references(context.data_dir)

    assert {:error, :direct_delivery_conflict} =
             Library.finish_direct_delivery(
               context.library,
               @frame_id,
               1,
               "shared",
               second,
               :displayed
             )

    assert {:error, :invalid_direct_delivery} =
             Library.finish_direct_delivery(
               context.library,
               @frame_id,
               1,
               "shared",
               first,
               :failed
             )

    assert [{"desired", ^first}] = references(context.data_dir)
  end

  test "read-only reconciliation keeps mismatches pending and commits confirmed display",
       context do
    digest = register_artifact!(context.library, <<9, 8, 7, 6, 5, 4>>)

    assert {:ok, %{"status" => "pending"}} =
             Library.begin_direct_delivery(
               context.library,
               @frame_id,
               digest,
               @profile_id,
               "reconcile-request"
             )

    base_options = [credential_resolver: {StaticCredentialResolver, nil}]

    assert {:ok, %{"targets" => [%{"directDelivery" => %{"status" => "pending"}}]}} =
             LocalAPI.execute_with_delivery(
               context.library,
               nil,
               %{"kind" => "reconcileDelivery", "targetID" => @frame_id},
               Keyword.put(base_options, :synchronizer, PendingSynchronizer)
             )

    assert {:ok, %{"status" => "pending"}} = Library.direct_delivery(context.library, @frame_id)

    assert {:ok, %{"targets" => [%{"directDelivery" => %{"status" => "displayed"}}]}} =
             LocalAPI.execute_with_delivery(
               context.library,
               nil,
               %{"kind" => "reconcileDelivery", "targetID" => @frame_id},
               Keyword.put(base_options, :synchronizer, ConfirmingSynchronizer)
             )

    assert {:ok, %{"status" => "displayed"}} =
             Library.direct_delivery(context.library, @frame_id)

    assert %{"entries" => audit} = Library.audit_page(context.library)
    displayed = Enum.find(audit, &(&1["operation"] == "direct.displayed"))
    attempts = Enum.filter(audit, &(&1["operation"] == "direct.attempt.started"))
    assert length(attempts) == 2
    assert hd(attempts)["attemptId"] != List.last(attempts)["attemptId"]
    assert displayed["attemptId"] == hd(attempts)["attemptId"]
  end

  test "a transport timeout leaves a durable desired asset for later reconciliation", context do
    digest = register_artifact!(context.library, <<1, 2, 3, 4, 5, 6>>)
    {:ok, frame} = Library.get_paired_frame(context.library, @frame_id)
    [profile | _] = frame["capabilities"]["storage"]["artifactProfiles"]

    assert {:error, :timeout} =
             DirectDelivery.push(
               context.library,
               frame,
               %{"digest" => digest},
               profile,
               "timed-out-push",
               credential_resolver: {StaticCredentialResolver, nil},
               synchronizer: TimedOutSynchronizer
             )

    assert {:ok, %{"request_id" => "timed-out-push", "status" => "pending"}} =
             Library.direct_delivery(context.library, @frame_id)

    assert %{"entries" => audit} = Library.audit_page(context.library)
    started = Enum.find(audit, &(&1["operation"] == "direct.attempt.started"))
    completed = Enum.find(audit, &(&1["operation"] == "direct.attempt.completed"))
    desired = Enum.find(audit, &(&1["operation"] == "direct.desired"))
    assert started["attemptId"] =~ ~r/\A[0-9a-f]{32}\z/
    assert completed["attemptId"] == started["attemptId"]
    assert completed["detail"] == %{"kind" => "push", "outcome" => "failed"}
    assert started["correlationId"] == desired["correlationId"]

    assert {:error, :invalid_direct_attempt} =
             Library.record_direct_attempt(
               context.library,
               @frame_id,
               "timed-out-push",
               "raw-id",
               :push,
               :started
             )

    assert {:error, :unknown_direct_attempt} =
             Library.record_direct_attempt(
               context.library,
               @frame_id,
               "timed-out-push",
               String.duplicate("c", 32),
               :push,
               :failed
             )

    assert [{"desired", ^digest}] = references(context.data_dir)
  end

  defp register_artifact!(library, bytes) do
    {:ok, master} =
      Library.import_master(library, bytes, %{
        title: "Direct delivery fixture",
        source_kind: :import,
        width: 2,
        height: 1,
        media_type: "image/png",
        provenance: %{"kind" => "test-fixture"}
      })

    {:ok, recipe_hash} =
      Library.register_recipe(library, :composition, %{"fixture" => Digest.sha256(bytes)}, [
        master["digest"]
      ])

    {:ok, artifact} =
      Library.register_artifact(library, bytes, %{
        master_digest: master["digest"],
        recipe_hash: recipe_hash,
        profile_id: @profile_id,
        renderer_revision: "direct-delivery-test-v1",
        media_type: "application/vnd.frameshift.rgb24"
      })

    artifact["digest"]
  end

  defp references(data_dir) do
    {:ok, connection} = Exqlite.start_link(database: Path.join(data_dir, "metadata.sqlite"))

    rows =
      connection
      |> Exqlite.query!(
        "SELECT role, object_digest FROM frame_asset_refs WHERE frame_id = ? ORDER BY role",
        [@frame_id]
      )
      |> Map.fetch!(:rows)
      |> Enum.map(fn [role, digest] -> {role, digest} end)

    GenServer.stop(connection)
    rows
  end
end
