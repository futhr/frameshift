defmodule Frameshift.Library.MaintenanceTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Library
  alias Frameshift.Library.Maintenance

  setup do
    root =
      Path.join(System.tmp_dir!(), "frameshift-maintenance-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root, data_dir: Path.join(root, "data")}
  end

  test "backup requires a real library and refuses a core socket", context do
    backup = Path.join(context.root, "backup")

    assert {:error, :library_not_found} =
             Maintenance.execute("backup", nil, backup, context.data_dir)

    {:ok, library} = Library.start_link(data_dir: context.data_dir, name: nil)
    File.write!(Path.join(context.data_dir, "core.sock"), "occupied")

    assert {:error, :core_socket_present} =
             Maintenance.execute("backup", nil, backup, context.data_dir)

    refute File.exists?(backup)
    File.rm!(Path.join(context.data_dir, "core.sock"))
    GenServer.stop(library)

    assert :ok = Maintenance.execute("backup", nil, backup, context.data_dir)
    assert :ok = Maintenance.execute("verify", backup, nil, context.data_dir)
  end

  test "distinguishes a live core socket from a stale socket", context do
    {:ok, library} = Library.start_link(data_dir: context.data_dir, name: nil)
    GenServer.stop(library)
    socket_path = Path.join(context.data_dir, "core.sock")

    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ifaddr: {:local, socket_path}])

    assert {:error, :core_socket_present} =
             Maintenance.execute(
               "backup",
               nil,
               Path.join(context.root, "backup"),
               context.data_dir
             )

    :gen_tcp.close(listener)

    assert :ok =
             Maintenance.execute(
               "backup",
               nil,
               Path.join(context.root, "backup"),
               context.data_dir
             )
  end

  test "restore publishes only to an absent, stopped directory", context do
    backup = Path.join(context.root, "backup")
    restored = Path.join(context.root, "restored")
    {:ok, library} = Library.start_link(data_dir: context.data_dir, name: nil)
    GenServer.stop(library)
    assert :ok = Maintenance.execute("backup", nil, backup, context.data_dir)

    assert :ok = File.mkdir_p(restored)
    File.write!(Path.join(restored, "core.sock"), "occupied")

    assert {:error, :core_socket_present} =
             Maintenance.execute("restore", backup, restored, context.data_dir)

    File.rm_rf!(restored)
    assert :ok = Maintenance.execute("restore", backup, restored, context.data_dir)
    assert File.regular?(Path.join(restored, "metadata.sqlite"))

    assert {:error, :backup_destination_exists} =
             Maintenance.execute("restore", backup, restored, context.data_dir)
  end

  test "rejects unsupported argument combinations", context do
    assert {:error, :invalid_arguments} =
             Maintenance.execute("backup", "unexpected", "backup", context.data_dir)

    assert {:error, :invalid_arguments} =
             Maintenance.execute("unknown", nil, nil, context.data_dir)
  end
end
