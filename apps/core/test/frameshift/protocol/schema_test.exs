defmodule Frameshift.Protocol.SchemaTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Protocol.Schema

  @fixtures_dir Path.expand("../../../../../protocol/fixtures", __DIR__)

  test "every declared schema compiles without network resolution" do
    for name <- Schema.names() do
      assert {:ok, %JSV.Root{}} = Schema.compiled(name)
    end
  end

  test "conformance fixtures have the declared validity" do
    manifest = decode_fixture("conformance.json")

    for fixture <- manifest["cases"] do
      document = decode_fixture(fixture["document"])
      result = Schema.validate(fixture["schema"], document)

      if fixture["valid"] do
        assert :ok = result, "expected #{fixture["document"]} to be valid"
      else
        assert {:error, _} = result,
               "expected #{fixture["document"]} to be invalid"
      end
    end
  end

  test "unknown schemas are rejected without creating atoms" do
    assert {:error, :unknown_schema} = Schema.validate("not-a-schema", %{})
  end

  defp decode_fixture(relative_path) do
    @fixtures_dir
    |> Path.join(relative_path)
    |> File.read!()
    |> JSON.decode!()
  end
end
