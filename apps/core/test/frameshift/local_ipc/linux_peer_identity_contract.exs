Code.require_file(Path.expand("../../../lib/frameshift/local_ipc/peer_identity.ex", __DIR__))

ExUnit.start()

defmodule Frameshift.LocalIPC.LinuxPeerIdentityContract do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Frameshift.LocalIPC.PeerIdentity

  test "reads the Linux kernel UID of the connected owner and another local user" do
    assert :os.type() == {:unix, :linux}
    path = "/tmp/frameshift-peer-#{System.unique_integer([:positive])}.sock"
    {:ok, listener} = :socket.open(:local, :stream, :default)

    on_exit(fn ->
      :socket.close(listener)
      File.rm(path)
    end)

    :ok = :socket.bind(listener, %{family: :local, path: path})
    :ok = :socket.listen(listener)
    :ok = File.chmod(path, 0o777)

    {:ok, local} = :socket.open(:local, :stream, :default)
    :ok = :socket.connect(local, %{family: :local, path: path})
    {:ok, accepted_local} = :socket.accept(listener, 10_000)
    assert {:ok, 0} = PeerIdentity.uid(accepted_local)

    assert {:ok, %{pid: local_pid, uid: 0, gid: 0}} =
             PeerIdentity.credentials(accepted_local)

    assert local_pid > 0
    :socket.close(accepted_local)
    :socket.close(local)

    client =
      Task.async(fn ->
        System.cmd("runuser", ["-u", "nobody", "--", "elixir", "-e", client_code(path)],
          stderr_to_stdout: true
        )
      end)

    {:ok, accepted_other} = :socket.accept(listener, 10_000)
    assert {:ok, 65_534} = PeerIdentity.uid(accepted_other)

    assert {:ok, %{pid: other_pid, uid: 65_534, gid: 65_534}} =
             PeerIdentity.credentials(accepted_other)

    assert other_pid != local_pid
    :socket.close(accepted_other)
    assert {_, 0} = Task.await(client, 10_000)
  end

  defp client_code(path) do
    "{:ok, socket} = :socket.open(:local, :stream, :default); " <>
      ":ok = :socket.connect(socket, %{family: :local, path: #{inspect(path)}}); " <>
      ":socket.close(socket)"
  end
end
