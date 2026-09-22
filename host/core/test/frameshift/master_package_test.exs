defmodule Frameshift.MasterPackageTest do
  use ExUnit.Case, async: true

  alias Frameshift.MasterPackage

  test "retains exact original and canonical bytes in a bounded deterministic container" do
    original = <<137, "PNG\r\n", 26, 10, 1, 2, 3>>
    rgba = <<255, 0, 0, 255, 0, 255, 0, 128>>

    assert {:ok, encoded} = MasterPackage.encode(original, rgba, 2, 1)
    package = IO.iodata_to_binary(encoded)

    assert {:ok, %{width: 2, height: 1, rgba: ^rgba, original: ^original}} =
             MasterPackage.decode(package)

    assert {:ok, repeated} = MasterPackage.encode(original, rgba, 2, 1)
    assert IO.iodata_to_binary(repeated) == package
  end

  test "rejects malformed lengths, dimensions, flags, and oversized declarations" do
    assert {:error, :invalid_rgba} = MasterPackage.encode("source", <<0, 0, 0>>, 1, 1)
    assert {:error, :invalid_dimensions} = MasterPackage.encode("source", <<>>, 0, 1)
    assert {:error, :invalid_master_package} = MasterPackage.decode("short")

    invalid_flags =
      <<"FSM1", 1::unsigned-big-16, 1::unsigned-big-16, 1::unsigned-big-32, 1::unsigned-big-32,
        4::unsigned-big-64, 1::unsigned-big-64, 0, 0, 0, 255, 1>>

    assert {:error, :invalid_master_package} = MasterPackage.decode(invalid_flags)

    invalid_length =
      <<"FSM1", 1::unsigned-big-16, 0::unsigned-big-16, 1::unsigned-big-32, 1::unsigned-big-32,
        8::unsigned-big-64, 1::unsigned-big-64, 0, 0, 0, 255, 1>>

    assert {:error, :invalid_master_package} = MasterPackage.decode(invalid_length)
  end
end
