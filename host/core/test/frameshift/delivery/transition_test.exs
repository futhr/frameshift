defmodule Frameshift.Delivery.TransitionTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Frameshift.Delivery.Transition

  @intent %{
    request_id: "command-1",
    desired_digest: "sha256:desired",
    profile_id: "photo-rgb24",
    status: "pending",
    revision: 3
  }

  test "one unresolved push intent prevents a conflicting replacement" do
    assert :insert = Transition.direct_request(nil, "digest", "profile", "new")

    assert {:reuse, @intent} =
             Transition.direct_request(
               @intent,
               @intent.desired_digest,
               @intent.profile_id,
               @intent.request_id
             )

    assert {:error, :request_id_conflict} =
             Transition.direct_request(@intent, "another", @intent.profile_id, "command-1")

    assert {:error, :direct_delivery_pending} =
             Transition.direct_request(@intent, "another", @intent.profile_id, "command-2")

    assert :insert =
             Transition.direct_request(
               %{@intent | status: "displayed"},
               "another",
               @intent.profile_id,
               "command-2"
             )
  end

  test "only an exact display confirmation can activate current" do
    assert :commit =
             Transition.direct_confirmation(
               @intent,
               3,
               "command-1",
               "sha256:desired",
               :displayed
             )

    assert :pending =
             Transition.direct_confirmation(@intent, 3, "command-1", "sha256:desired", :pending)

    assert :already =
             Transition.direct_confirmation(
               %{@intent | status: "displayed"},
               3,
               "command-1",
               "sha256:desired",
               :displayed
             )
  end

  property "a different revision, request, or digest never commits" do
    check all(
            revision <- integer(4..1_000),
            request_id <- string(:alphanumeric, min_length: 1),
            digest <- string(:alphanumeric, min_length: 1),
            max_runs: 100
          ) do
      assert {:error, :direct_delivery_conflict} =
               Transition.direct_confirmation(
                 @intent,
                 revision,
                 request_id,
                 digest,
                 :displayed
               )
    end
  end

  test "pull activation requires matching revision, verified storage, and current digest" do
    manifest = %{"revision" => 9, "desiredAsset" => "sha256:art"}

    ack = %{
      "manifestRevision" => 9,
      "storage" => "verified",
      "refresh" => "displayed",
      "currentAsset" => "sha256:art"
    }

    assert :commit = Transition.pull_confirmation(manifest, ack)
    assert :pending = Transition.pull_confirmation(manifest, Map.put(ack, "refresh", "failed"))

    assert :pending =
             Transition.pull_confirmation(manifest, Map.put(ack, "refresh", "not-requested"))

    assert {:error, :invalid_acknowledgement} =
             Transition.pull_confirmation(manifest, Map.put(ack, "refresh", "pending"))

    assert {:error, :outbox_revision_conflict} =
             Transition.pull_confirmation(manifest, Map.put(ack, "manifestRevision", 8))

    assert {:error, :storage_not_verified} =
             Transition.pull_confirmation(manifest, Map.put(ack, "storage", "failed"))

    assert {:error, :current_asset_mismatch} =
             Transition.pull_confirmation(manifest, Map.put(ack, "currentAsset", "sha256:other"))
  end
end
