defmodule FrameshiftBuild.AssemblyTest do
  @moduledoc false

  use ExUnit.Case, async: true

  @fixture File.read!(Path.join(__DIR__, "fixtures/assembly-v1.json"))
  @identity "sha256:9be6b6faa2c8f8bc87f1bde825e257a51728710dd424d0f71f0275be9e3b3a20"

  test "assembly golden identity and exact unique resolution pins survive packaging" do
    assert FrameshiftBuild.build_identity(@fixture) == {:ok, @identity}
    assert {:ok, pins} = FrameshiftBuild.profile_pins(@fixture)

    assert pins == [
             "sha256:" <> String.duplicate("a", 64),
             "sha256:" <> String.duplicate("b", 64)
           ]

    assert :frameshift_build@assembly in Application.spec(:frameshift_build, :modules)
    refute :assembly_fixture in Application.spec(:frameshift_build, :modules)
  end

  test "physical inputs change identity without following catalog revisions" do
    for {from, to} <- [
          {"\"x_um\":0", "\"x_um\":1"},
          {"\"dwell_ms\":600000", "\"dwell_ms\":600001"},
          {"\"mounting\":\"wall\"", "\"mounting\":\"stand\""},
          {String.duplicate("a", 64), String.duplicate("c", 64)}
        ] do
      assert {:ok, identity} = FrameshiftBuild.build_identity(String.replace(@fixture, from, to))
      refute identity == @identity
    end
  end

  test "boundary refusals do not echo malformed input" do
    for value <- [nil, 1, %{}, <<255>>, "{}"] do
      assert {:error, "invalid_document"} = FrameshiftBuild.build_identity(value)
      assert {:error, "invalid_document"} = FrameshiftBuild.profile_pins(value)
    end

    assert {:error, "noncanonical"} = FrameshiftBuild.build_identity(" " <> @fixture)

    assert {:error, "unsupported_semantics"} =
             FrameshiftBuild.build_identity(
               String.replace(@fixture, "frameshift-physical-1", "latest")
             )
  end
end
