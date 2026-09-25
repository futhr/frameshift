defmodule FrameshiftBuild.MappingTest do
  @moduledoc false
  use ExUnit.Case, async: true

  @fixture File.read!(Path.join(__DIR__, "fixtures/mapping-v1.json"))
  @identity "sha256:823315f13db255db83b81f9977962c90fec76d6cbd8dba66eb315b74049a8b2d"

  test "mapping identity matches the browser and changes with its scope and sources" do
    assert {:ok, @identity} == FrameshiftBuild.mapping_identity(@fixture)

    for {from, to} <- [
          {"fixture-fw-0", "fixture-fw-1"},
          {"fixture-rgb24", "other-format"},
          {"fixture-protocol", "other-protocol"},
          {"test-1", "test-2"},
          {"out-0", "out-1"},
          {"sha256:" <> String.duplicate("a", 64), "sha256:" <> String.duplicate("b", 64)}
        ] do
      assert {:ok, changed} = FrameshiftBuild.mapping_identity(String.replace(@fixture, from, to))
      refute changed == @identity
    end
  end

  test "inspection preserves exact pin, runtime selections and source citations" do
    assert {:ok, value} = FrameshiftBuild.inspect_mapping(@fixture)
    assert value.identity == @identity
    assert value.profile == "sha256:" <> String.duplicate("a", 64)
    assert value.artifact == "fixture-rgb24"
    assert value.firmware == "fixture-fw-0"
    assert value.protocol == "fixture-protocol"
    assert value.pairs == [%{input: "in-0", output: "out-0"}]

    assert [%{"evidence" => "custom", "locator" => "fixture-only", "revision" => "test-1"}] =
             value.sources

    assert {:error, "noncanonical"} = FrameshiftBuild.inspect_mapping(" " <> @fixture)
    assert {:error, "invalid_document"} = FrameshiftBuild.inspect_mapping(nil)
  end

  test "malformed values, size limits and mutable fields return bounded refusals" do
    for value <- [nil, %{}, 1, <<255>>, "{}", "\"\\uD800\""] do
      assert {:error, "invalid_document"} = FrameshiftBuild.mapping_identity(value)
    end

    assert {:error, "too_large"} =
             FrameshiftBuild.mapping_identity(String.duplicate(" ", 262_145))

    assert {:error, "too_deep"} = FrameshiftBuild.mapping_identity(String.duplicate("[", 17))

    for key <- ["approved", "revoked", "label", "price", "expires_at"] do
      changed = String.replace(@fixture, "\"schema\":1", "\"schema\":1,\"#{key}\":true")
      assert {:error, "noncanonical"} = FrameshiftBuild.mapping_identity(changed)
    end
  end
end
