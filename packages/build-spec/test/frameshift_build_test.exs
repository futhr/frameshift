defmodule FrameshiftBuildTest do
  @moduledoc false

  use ExUnit.Case, async: true

  @fixture File.read!(Path.join(__DIR__, "fixtures/profile-v1.json"))
  @identity "sha256:bca6740b4b3726d310ef42735c1d45f40682f767816ff299f02ed6a4143d2278"

  test "standard SHA-256 identity matches the browser golden fixture" do
    assert FrameshiftBuild.profile_identity(@fixture) == {:ok, @identity}
    changed = String.replace(@fixture, "\"part_revision\":\"R1\"", "\"part_revision\":\"R2\"")
    assert {:ok, identity} = FrameshiftBuild.profile_identity(changed)
    refute identity == @identity
  end

  test "malformed and non-string boundaries return bounded errors" do
    for input <- [nil, %{}, 1, <<255>>, "{}", "\"\\uD800\""] do
      assert {:error, "invalid_document"} = FrameshiftBuild.profile_identity(input)
    end

    assert {:error, "noncanonical"} = FrameshiftBuild.profile_identity(" " <> @fixture)

    assert {:error, "too_large"} =
             FrameshiftBuild.profile_identity(String.duplicate(" ", 262_145))
  end

  test "packaged modules exclude Gleam test runners" do
    modules = Application.spec(:frameshift_build, :modules)
    assert :frameshift_build in modules
    assert :gleam_json_ffi in modules
    refute :profile_fixture in modules
    refute :profile_parity in modules
    refute :frameshift_build_test in modules
  end
end
