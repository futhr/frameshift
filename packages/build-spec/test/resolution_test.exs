defmodule FrameshiftBuild.ResolutionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  @profile File.read!(Path.join(__DIR__, "fixtures/profile-v1.json"))
  @plan File.read!(Path.join(__DIR__, "fixtures/assembly-v1.json"))

  test "resolves all exact content pins independently of input order" do
    {plan, profiles, _} = fixture()
    assert {:ok, result} = FrameshiftBuild.resolve_build(plan, profiles)
    assert {:ok, ^result} = FrameshiftBuild.resolve_build(plan, Enum.reverse(profiles))
    assert {:ok, result.identity} == FrameshiftBuild.build_identity(plan)
    assert {:resolution, _, [_, _], []} = result.resolution
  end

  test "missing profiles remain unresolved instead of following a newer revision" do
    {plan, [first, _], [_, missing]} = fixture()
    assert {:ok, result} = FrameshiftBuild.resolve_build(plan, [first])
    assert {:resolution, _, [_], [^missing]} = result.resolution
    assert {:ok, empty} = FrameshiftBuild.resolve_build(plan, [])
    assert {:resolution, _, [], [_, _]} = empty.resolution
    newer = String.replace(first, "\"part_revision\":\"R1\"", "\"part_revision\":\"R2\"")
    assert {:error, "unreferenced_profile"} = FrameshiftBuild.resolve_build(plan, [newer])
  end

  test "tampering, duplicate bodies and caller-supplied digests cannot bind pins" do
    {plan, [first, second], [pin, _]} = fixture()
    assert {:error, "duplicate_identifier"} = FrameshiftBuild.resolve_build(plan, [first, first])
    assert {:error, "noncanonical"} = FrameshiftBuild.resolve_build(plan, [first <> " ", second])

    assert {:error, "invalid_document"} =
             FrameshiftBuild.resolve_build(plan, [%{identity: pin, canonical: second}])

    changed = String.replace(first, "\"max\":1010", "\"max\":1011")

    assert {:error, "unreferenced_profile"} =
             FrameshiftBuild.resolve_build(plan, [changed, second])
  end

  test "type, count, document and total byte limits fail before hashing" do
    for profiles <- [nil, %{}, [nil], [@profile | :improper]] do
      assert {:error, "invalid_document"} = FrameshiftBuild.resolve_build(@plan, profiles)
    end

    assert {:error, "invalid_count"} =
             FrameshiftBuild.resolve_build(@plan, List.duplicate("", 65))

    assert {:error, "too_large"} =
             FrameshiftBuild.resolve_build(@plan, [String.duplicate(" ", 262_145)])

    assert {:error, "too_large"} =
             FrameshiftBuild.resolve_build(
               @plan,
               List.duplicate(String.duplicate(" ", 262_144), 16)
             )

    assert {:error, "invalid_document"} = FrameshiftBuild.resolve_build(nil, [])
  end

  defp fixture do
    second = String.replace(@profile, "\"id\":\"fixture-0\"", "\"id\":\"fixture-1\"")
    {:ok, first_id} = FrameshiftBuild.profile_identity(@profile)
    {:ok, second_id} = FrameshiftBuild.profile_identity(second)

    plan =
      @plan
      |> String.replace("sha256:" <> String.duplicate("a", 64), first_id)
      |> String.replace("sha256:" <> String.duplicate("b", 64), second_id)

    {plan, [@profile, second], [first_id, second_id]}
  end
end
