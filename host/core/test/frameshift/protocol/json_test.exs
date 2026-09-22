defmodule Frameshift.Protocol.JSONTest do
  use ExUnit.Case, async: true

  alias Frameshift.Protocol.JSON, as: ProtocolJSON

  @valid_desired ~S({
    "assetDigest":"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    "artifactProfile":"urn:frameshift:profile:sim-rgb24-v1",
    "requestId":"request-0001"
  })

  test "decodes a bounded schema-valid control document" do
    assert {:ok, document} = ProtocolJSON.decode_control(@valid_desired, "desired")
    assert document["requestId"] == "request-0001"
  end

  test "rejects duplicate object names before schema validation" do
    duplicate = ~S({"requestId":"one","requestId":"two"})
    assert {:error, :invalid_json} = ProtocolJSON.decode_control(duplicate, "desired")
  end

  test "rejects control documents over 64 KiB" do
    oversized = "{" <> String.duplicate(" ", 64 * 1024) <> "}"
    assert {:error, :body_too_large} = ProtocolJSON.decode_control(oversized, "desired")
  end

  test "rejects nesting deeper than 32 before decoding" do
    nested = String.duplicate("[", 33) <> String.duplicate("]", 33)
    assert {:error, :nesting_too_deep} = ProtocolJSON.decode_control(nested, "desired")
  end

  test "does not count brackets inside strings as nesting" do
    invalid_for_schema = ~S({"value":"[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[["})

    assert {:error, {:schema, _reason}} =
             ProtocolJSON.decode_control(invalid_for_schema, "desired")
  end

  test "rejects unknown schemas without atom creation" do
    assert {:error, :unknown_schema} = ProtocolJSON.decode_control("{}", "missing")
  end

  test "canonical encoding is independent of map insertion order" do
    left = %{"b" => 2, "a" => 1}
    right = Map.new(Enum.reverse(Map.to_list(left)))

    assert {:ok, ~S({"a":1,"b":2})} = ProtocolJSON.encode(left)
    assert ProtocolJSON.encode(left) == ProtocolJSON.encode(right)
  end
end
