defmodule FrameshiftBuild.LayoutTest do
  @moduledoc false

  use ExUnit.Case, async: true

  @root Path.join(__DIR__, "fixtures")
  @layout File.read!(Path.join(@root, "layout-v1.json"))
  @assembly File.read!(Path.join(@root, "context-v1/assembly.json"))
  @profiles Enum.map(0..3, &File.read!(Path.join(@root, "context-v1/profile-#{&1}.json")))
  @mappings Enum.map(0..1, &File.read!(Path.join(@root, "context-v1/mapping-#{&1}.json")))
  @canonical File.read!(Path.join(@root, "context-v1/context-layout.json"))
  @layout_id "sha256:9acb1b67fb0039448fb57f65f344be4ac0f33ca4f7ca49eaeed14db87e5bde01"
  @context_id "sha256:69c6b95344c12fc9690e3a0d22ebf485c9931aa6d2c1f8923faa3b8d53e5ea3d"

  test "layout and combined context match browser golden identities" do
    assert {:ok, @layout_id} == FrameshiftBuild.layout_identity(@layout)

    assert {:ok, value} =
             FrameshiftBuild.resolve_context(@assembly, @profiles, @mappings, [@layout])

    assert value.identity == @context_id
    assert value.canonical == @canonical
    assert {:context, _, [_, _], [{:layout, @layout_id, _}]} = value.context

    assert {:ok, ^value} =
             FrameshiftBuild.resolve_context(
               @assembly,
               Enum.reverse(@profiles),
               Enum.reverse(@mappings),
               [@layout]
             )

    changed = String.replace(@layout, "\"x\":0", "\"x\":1")

    assert {:ok, revision} =
             FrameshiftBuild.resolve_context(@assembly, @profiles, @mappings, [changed])

    refute revision.identity == @context_id
    assert revision.assembly_identity == value.assembly_identity
  end

  test "stale scope and duplicate assignments refuse while missing profiles remain explicit" do
    for changed <- [
          String.replace(@layout, "\"controller\":\"controller\"", "\"controller\":\"absent\""),
          String.replace(@layout, "\"display\":\"panel\"", "\"display\":\"absent\""),
          String.replace(@layout, "fixture-v1", "other-runtime")
        ] do
      assert {:error, "invalid_reference"} =
               FrameshiftBuild.resolve_context(@assembly, @profiles, @mappings, [changed])
    end

    assert {:error, "duplicate_identifier"} =
             FrameshiftBuild.resolve_context(@assembly, @profiles, @mappings, [@layout, @layout])

    assert {:error, "duplicate_identifier"} =
             FrameshiftBuild.resolve_context(@assembly, @profiles, @mappings, [
               @layout,
               String.replace(@layout, "\"x\":0", "\"x\":1")
             ])

    assert {:ok, %{context: {:context, {:resolution, _, [], [_, _, _, _]}, [], [_]}}} =
             FrameshiftBuild.resolve_context(@assembly, [], [], [@layout])
  end

  test "malformed input and all document groups share bounded admission" do
    for bad <- [nil, %{}, [nil], ["x" | :improper]] do
      assert {:error, "invalid_document"} =
               FrameshiftBuild.resolve_context(@assembly, @profiles, @mappings, bad)
    end

    for bad <- [nil, %{}, <<255>>, "{}", "\"\\uD800\""] do
      assert {:error, "invalid_document"} = FrameshiftBuild.layout_identity(bad)
    end

    assert {:error, "noncanonical"} = FrameshiftBuild.layout_identity(" " <> @layout)

    assert {:error, "invalid_count"} =
             FrameshiftBuild.resolve_context(@assembly, [], [], List.duplicate("", 65))

    assert {:error, "too_large"} =
             FrameshiftBuild.resolve_context(@assembly, [], [], [String.duplicate("x", 262_145)])

    body = String.duplicate("x", 262_144)

    assert {:error, "too_large"} =
             FrameshiftBuild.resolve_context(
               @assembly,
               List.duplicate(body, 6),
               List.duplicate(body, 5),
               List.duplicate(body, 5)
             )
  end
end
