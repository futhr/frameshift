defmodule FrameshiftBuild.ContextTest do
  @moduledoc false
  use ExUnit.Case, async: true

  @root Path.join(__DIR__, "fixtures/context-v1")
  @assembly File.read!(Path.join(@root, "assembly.json"))
  @profiles Enum.map(0..3, &File.read!(Path.join(@root, "profile-#{&1}.json")))
  @mappings Enum.map(0..1, &File.read!(Path.join(@root, "mapping-#{&1}.json")))
  @canonical File.read!(Path.join(@root, "context.json"))
  @identity "sha256:6c3d7e88b4bdb95515f95d28448d3814e1b798c6d7203db3c825c28d17451e23"

  test "exact scope and source bindings produce the browser golden context" do
    assert {:ok, value} = FrameshiftBuild.resolve_context(@assembly, @profiles, @mappings)
    assert value.identity == @identity
    assert value.canonical == @canonical
    assert {:ok, value.assembly_identity} == FrameshiftBuild.build_identity(@assembly)
    assert {:context, {:resolution, _, [_, _, _, _], []}, [_, _]} = value.context

    assert {:ok, ^value} =
             FrameshiftBuild.resolve_context(
               @assembly,
               Enum.reverse(@profiles),
               Enum.reverse(@mappings)
             )
  end

  test "mapping sources change context without rewriting assembly identity" do
    [first, second] = @mappings
    changed = String.replace(first, "test-1", "test-2")
    assert {:ok, value} = FrameshiftBuild.resolve_context(@assembly, @profiles, [changed, second])
    refute value.identity == @identity
    assert {:ok, value.assembly_identity} == FrameshiftBuild.build_identity(@assembly)
  end

  test "stale scope, ambiguous revisions and absent ports refuse" do
    [first, _] = @mappings
    assert {:ok, scope} = FrameshiftBuild.inspect_mapping(first)

    for changed <- [
          String.replace(first, scope.profile, "sha256:" <> String.duplicate("9", 64)),
          String.replace(first, "\"firmware\":\"#{scope.firmware}\"", "\"firmware\":\"other\""),
          String.replace(first, "\"input\":\"in\"", "\"input\":\"absent\"")
        ] do
      assert {:error, "invalid_reference"} =
               FrameshiftBuild.resolve_context(@assembly, @profiles, [changed])
    end

    assert {:error, "duplicate_identifier"} =
             FrameshiftBuild.resolve_context(@assembly, @profiles, [first, first])

    assert {:error, "duplicate_identifier"} =
             FrameshiftBuild.resolve_context(@assembly, @profiles, [
               first,
               String.replace(first, "test-1", "test-2")
             ])

    assert {:error, "noncanonical"} =
             FrameshiftBuild.resolve_context(@assembly, @profiles, [first <> " "])
  end

  test "unresolved profiles remain explicit and cannot support supplied mappings" do
    assert {:ok, value} = FrameshiftBuild.resolve_context(@assembly, [], [])
    assert {:context, {:resolution, _, [], [_, _, _, _]}, []} = value.context
    refute value.identity == @identity

    assert {:error, "invalid_reference"} =
             FrameshiftBuild.resolve_context(@assembly, [], @mappings)
  end

  test "combined document budgets and input types fail before parsing" do
    for bad <- [nil, %{}, [nil], ["body" | :improper], [%{identity: "fake", bytes: "{}"}]] do
      assert {:error, "invalid_document"} =
               FrameshiftBuild.resolve_context(@assembly, @profiles, bad)

      assert {:error, "invalid_document"} =
               FrameshiftBuild.resolve_context(@assembly, bad, @mappings)
    end

    assert {:error, "invalid_document"} = FrameshiftBuild.resolve_context(nil, [], [])

    assert {:error, "invalid_count"} =
             FrameshiftBuild.resolve_context(@assembly, [], List.duplicate("", 65))

    assert {:error, "too_large"} =
             FrameshiftBuild.resolve_context(@assembly, [], [String.duplicate("x", 262_145)])

    bodies = List.duplicate(String.duplicate("x", 262_144), 8)
    assert {:error, "too_large"} = FrameshiftBuild.resolve_context(@assembly, bodies, bodies)
  end
end
