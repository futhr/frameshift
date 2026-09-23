defmodule Frameshift.Qualification.IdentityTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Digest
  alias Frameshift.Qualification.Identity

  @binding %{
    "schemaVersion" => 1,
    "frameId" => "sim-photo-00000001",
    "thingDescriptionDigest" => Digest.sha256("td"),
    "profileId" => "urn:frameshift:profile:sim-rgb24-v1",
    "profileDigest" => Digest.sha256("profile"),
    "rendererBuildDigest" => Digest.sha256("binary"),
    "rendererProtocolRevision" => "fsr1",
    "rendererAlgorithmRevision" => "frameshift-raster-v0.1",
    "bindingDigest" => Digest.sha256("form contract"),
    "connectorRevision" => "wotex-http-v0.1",
    "effectClass" => "physical_display",
    "transferMode" => "push"
  }

  test "a binding is canonical, bounded, and changes with profile or renderer build" do
    assert {:ok, first} = Identity.binding(@binding)
    assert {:ok, ^first} = Identity.binding(Map.new(Enum.reverse(Map.to_list(@binding))))

    assert {:ok, profile_changed} =
             Identity.binding(%{@binding | "profileDigest" => Digest.sha256("new profile")})

    assert {:ok, renderer_changed} =
             Identity.binding(%{@binding | "rendererBuildDigest" => Digest.sha256("new binary")})

    refute first.digest == profile_changed.digest
    refute first.digest == renderer_changed.digest

    assert {:error, :invalid_qualification} =
             Identity.binding(Map.put(@binding, "credentialRef", "private-ref"))

    assert {:error, :unsupported_qualification_version} =
             Identity.binding(%{@binding | "schemaVersion" => 2})
  end

  test "work and result preserve separate source, recipe, binding and wire identities" do
    {:ok, binding} = Identity.binding(@binding)
    master = Digest.sha256("master")
    recipe = Digest.sha256("recipe")
    artifact = Digest.sha256("wire bytes")

    assert {:ok, work} = Identity.work(binding.digest, master, recipe)
    assert {:ok, ^work} = Identity.work(binding.digest, master, recipe)
    assert {:ok, other} = Identity.work(binding.digest, master, Digest.sha256("other recipe"))
    refute work.digest == other.digest

    assert {:ok, result} = Identity.result(work.digest, artifact, 10, "image/rgb24")
    assert result.document["artifactDigest"] == artifact
    refute result.digest == artifact
    assert {:error, :invalid_qualification} = Identity.work("bad", master, recipe)

    assert {:error, :invalid_qualification} =
             Identity.result(work.digest, artifact, -1, "image/rgb24")
  end
end
