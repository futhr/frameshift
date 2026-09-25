defmodule FrameshiftBuild.PlanningPreviewTest do
  @moduledoc false

  use ExUnit.Case, async: true

  @root Path.join(__DIR__, "fixtures/context-v1")
  @assembly File.read!(Path.join(@root, "assembly.json"))
  @profiles Enum.map(0..3, &File.read!(Path.join(@root, "profile-#{&1}.json")))
  @mappings Enum.map(0..1, &File.read!(Path.join(@root, "mapping-#{&1}.json")))

  test "verified context feeds every stage with stable identity and findings" do
    assert {:ok, result} = FrameshiftBuild.planning_preview(@assembly, @profiles, @mappings)
    assert result.status in ["unknown", "incompatible"]
    assert {:ok, context} = FrameshiftBuild.resolve_context(@assembly, @profiles, @mappings)
    assert result.identity == context.identity

    assert Enum.map(result.stages, fn {:stage, name, _} -> name end) == [
             "graph",
             "completeness",
             "geometry",
             "viewing",
             "power_interfaces",
             "power_loads",
             "power_contracts",
             "thermal",
             "mounting",
             "signals",
             "signal_routes",
             "operation",
             "artifacts"
           ]

    assert Enum.any?(result.stages, fn {:stage, _, findings} -> findings != [] end)

    assert {:ok, ^result} =
             FrameshiftBuild.planning_preview(
               @assembly,
               Enum.reverse(@profiles),
               Enum.reverse(@mappings)
             )
  end

  test "changed source bytes and malformed context refuse before preview" do
    [first | rest] = @profiles
    changed = String.replace(first, "\"part_revision\":\"R1\"", "\"part_revision\":\"R2\"")

    assert {:error, "unreferenced_profile"} =
             FrameshiftBuild.planning_preview(@assembly, [changed | rest], @mappings)

    assert {:error, "invalid_document"} =
             FrameshiftBuild.planning_preview(@assembly, @profiles, [nil])
  end
end
