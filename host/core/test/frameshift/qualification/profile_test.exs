defmodule Frameshift.Qualification.ProfileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Qualification.Profile

  @fixture Path.expand("../../../../../protocol/fixtures/valid/thing-description.json", __DIR__)

  test "profile identity changes with byte-affecting fields but not available storage" do
    capabilities =
      File.read!(@fixture) |> Jason.decode!() |> Map.fetch!("frameshift:capabilities")

    profile_id = "urn:frameshift:profile:sim-rgb24-v1"

    assert {:ok, original} = Profile.digest(capabilities, profile_id)

    available_changed = put_in(capabilities, ["storage", "availableBytes"], 0)
    assert {:ok, ^original} = Profile.digest(available_changed, profile_id)

    color_changed = put_in(capabilities, ["color", "profileRevision"], "sim-srgb-v2")
    assert {:ok, color_digest} = Profile.digest(color_changed, profile_id)
    refute original == color_digest

    profile_changed =
      update_in(capabilities, ["storage", "artifactProfiles"], fn [profile] ->
        [%{profile | "rowAlignment" => 4}]
      end)

    assert {:ok, packing_digest} = Profile.digest(profile_changed, profile_id)
    refute original == packing_digest
    assert {:error, :unsupported_profile} = Profile.digest(capabilities, "missing")
  end
end
