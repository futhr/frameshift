defmodule Frameshift.FrameRegistryTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.FrameRegistry

  @fixture Path.expand("../../../../protocol/fixtures/valid/thing-description.json", __DIR__)
  @fingerprint "sha256:" <> String.duplicate("a", 64)

  test "admits a universal TD and preserves optional extension data" do
    source =
      @fixture
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("vendor:measuredPanelRevision", "panel-a3")
      |> Jason.encode!()

    assert {:ok, frame} =
             FrameRegistry.admit(source, "keychain:frame-client-0001", @fingerprint)

    assert frame.frame_id == "sim-photo-00000001"
    assert frame.medium == "photo"
    assert frame.server_spki_fingerprint == @fingerprint
    assert JSON.decode!(frame.td_json)["vendor:measuredPanelRevision"] == "panel-a3"
    assert JSON.decode!(frame.capabilities_json)["stillOnly"]
  end

  test "rejects invalid identity custody and unsupported semantic contracts" do
    source = File.read!(@fixture)

    assert {:error, :invalid_credential_reference} =
             FrameRegistry.admit(source, "", @fingerprint)

    assert {:error, :invalid_credential_reference} =
             FrameRegistry.admit(source, String.duplicate("x", 1_025), @fingerprint)

    assert {:error, :invalid_server_fingerprint} =
             FrameRegistry.admit(source, "keychain:frame", "sha256:UPPERCASE")

    missing_profile =
      source
      |> Jason.decode!()
      |> Map.delete("profile")
      |> Jason.encode!()

    assert {:error, %Frameshift.Protocol.Thing.Error{code: :required_profile_missing}} =
             FrameRegistry.admit(
               missing_profile,
               "keychain:frame",
               @fingerprint
             )
  end

  test "paired admission distinguishes replay from identity and pin conflicts" do
    assert {:ok, candidate} =
             FrameRegistry.admit(File.read!(@fixture), "keychain:frame-client-0001", @fingerprint)

    existing = Map.new(candidate, fn {key, value} -> {Atom.to_string(key), value} end)
    same_owner = {:ok, %{"frame_id" => candidate.frame_id}}
    other_owner = {:ok, %{"frame_id" => "other-frame"}}

    assert :insert = FrameRegistry.admission_decision(candidate, nil, :not_found, :not_found)
    assert :reuse = FrameRegistry.admission_decision(candidate, existing, same_owner, same_owner)

    assert {:error, :paired_frame_conflict} =
             FrameRegistry.admission_decision(
               %{candidate | credential_ref: "keychain:replacement"},
               existing,
               same_owner,
               same_owner
             )

    assert {:error, :server_fingerprint_in_use} =
             FrameRegistry.admission_decision(candidate, nil, other_owner, :not_found)

    assert {:error, :thing_identity_in_use} =
             FrameRegistry.admission_decision(candidate, nil, :not_found, other_owner)
  end
end
