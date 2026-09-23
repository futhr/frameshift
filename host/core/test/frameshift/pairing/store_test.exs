defmodule Frameshift.Pairing.StoreTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Pairing.{Store, Window}

  @device_id "frame-000000000001"
  @secret <<1::128>>

  setup do
    data_dir =
      Path.join(
        System.tmp_dir!(),
        "frameshift-pairing-store-#{System.unique_integer([:positive, :monotonic])}"
      )

    File.mkdir_p!(data_dir)
    on_exit(fn -> File.rm_rf!(data_dir) end)
    %{data_dir: data_dir}
  end

  test "consumed secret and host identity survive restart without using a supplied old secret", %{
    data_dir: data_dir
  } do
    assert {:ok, window} = Store.load_or_create(data_dir, @device_id, @secret)
    assert window.secret == @secret

    paired = %{
      window
      | secret: nil,
        host_certificate_fingerprint: "sha256:" <> String.duplicate("a", 64),
        paired_request_id: "pair-1"
    }

    assert :ok = Store.save(data_dir, paired)
    assert {:ok, ^paired} = Store.load_or_create(data_dir, @device_id, @secret)

    path = Path.join(data_dir, "pairing-authority.json")
    assert {:ok, %File.Stat{mode: mode}} = File.lstat(path)
    assert Bitwise.band(mode, 0o077) == 0
    refute File.read!(path) =~ Base.encode64(@secret)
  end

  test "a corrupt authority fails closed rather than resurrecting a bootstrap secret", %{
    data_dir: data_dir
  } do
    assert {:ok, %Window{}} = Store.load_or_create(data_dir, @device_id, @secret)
    path = Path.join(data_dir, "pairing-authority.json")
    File.write!(path, "damaged")

    assert {:error, :corrupt_pairing_authority} =
             Store.load_or_create(data_dir, @device_id, @secret)
  end

  test "an insecure authority or mismatched device identity fails closed", %{data_dir: data_dir} do
    assert {:ok, %Window{}} = Store.load_or_create(data_dir, @device_id, @secret)
    path = Path.join(data_dir, "pairing-authority.json")

    assert {:error, :corrupt_pairing_authority} =
             Store.load_or_create(data_dir, "another-frame-000001", @secret)

    File.chmod!(path, 0o644)

    assert {:error, :insecure_pairing_authority} =
             Store.load_or_create(data_dir, @device_id, @secret)
  end
end
