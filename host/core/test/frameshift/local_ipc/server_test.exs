defmodule Frameshift.LocalIPC.ServerTest do
  use ExUnit.Case, async: true

  alias Frameshift.Library
  alias Frameshift.LocalIPC.Server

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-local-ipc-test-#{System.unique_integer([:positive, :monotonic])}"
      )

    data_dir = Path.join(root, "library")
    socket_path = Path.join(root, "run/core.sock")
    {:ok, task_supervisor} = Task.Supervisor.start_link()
    {:ok, library} = Library.start_link(data_dir: data_dir, name: nil)

    {:ok, server} =
      Server.start_link(
        path: socket_path,
        library: library,
        task_supervisor: task_supervisor,
        name: nil
      )

    on_exit(fn ->
      for process <- [server, library, task_supervisor], Process.alive?(process) do
        stop_process(process)
      end

      File.rm_rf!(root)
    end)

    %{server: server, socket_path: socket_path}
  end

  test "serves one correlated bounded snapshot over a private Unix socket", context do
    request_id = "88e55c07-d08a-4c6e-9a9e-483d3ae68cd5"

    response =
      request(context.socket_path, %{
        "version" => 1,
        "requestId" => request_id,
        "operation" => "snapshot"
      })

    assert %{
             "version" => 1,
             "requestId" => ^request_id,
             "ok" => true,
             "snapshot" => %{"items" => [], "targets" => []}
           } = response

    assert %File.Stat{type: :other, mode: mode} = File.lstat!(context.socket_path)
    assert Bitwise.band(mode, 0o777) == 0o600
    assert Bitwise.band(File.stat!(Path.dirname(context.socket_path)).mode, 0o777) == 0o700
  end

  test "executes a command and returns the authoritative snapshot", context do
    response =
      request(context.socket_path, %{
        "version" => 1,
        "requestId" => "request-2",
        "operation" => "command",
        "command" => %{
          "kind" => "updateInstruction",
          "instruction" => "Stored by the core"
        }
      })

    assert response["ok"]
    assert response["snapshot"]["instruction"] == "Stored by the core"

    refreshed =
      request(context.socket_path, %{
        "version" => 1,
        "requestId" => "request-3",
        "operation" => "snapshot"
      })

    assert refreshed["snapshot"]["instruction"] == "Stored by the core"
  end

  test "rejects duplicate JSON members and unknown request fields", context do
    duplicate =
      ~s({"version":1,"requestId":"one","requestId":"two","operation":"snapshot"})

    assert %{"ok" => false, "error" => %{"code" => "invalid_request"}} =
             request_bytes(context.socket_path, duplicate)

    assert %{
             "ok" => false,
             "requestId" => "request-4",
             "error" => %{"code" => "invalid_request"}
           } =
             request(context.socket_path, %{
               "version" => 1,
               "requestId" => "request-4",
               "operation" => "snapshot",
               "secret" => "must-not-be-accepted"
             })
  end

  test "does not replace a non-socket filesystem entry" do
    root = "/tmp/fs-u-#{System.unique_integer([:positive, :monotonic])}"

    path = Path.join(root, "core.sock")
    File.mkdir_p!(root)
    File.write!(path, "owner data")
    on_exit(fn -> File.rm_rf!(root) end)

    previous = Process.flag(:trap_exit, true)
    assert {:error, :unsafe_socket_path} = Server.start_link(path: path, name: nil)
    Process.flag(:trap_exit, previous)
    assert File.read!(path) == "owner data"
  end

  defp request(path, document) do
    document
    |> RFC8785.encode!()
    |> then(&request_bytes(path, &1))
  end

  defp request_bytes(path, bytes) do
    {:ok, socket} =
      :gen_tcp.connect({:local, path}, 0, [
        :binary,
        {:packet, 4},
        {:packet_size, 1024 * 1024},
        {:active, false}
      ])

    :ok = :gen_tcp.send(socket, bytes)
    {:ok, response} = :gen_tcp.recv(socket, 0, 5_000)
    :gen_tcp.close(socket)
    Jason.decode!(response)
  end

  defp stop_process(process) do
    GenServer.stop(process)
  catch
    :exit, _reason -> :ok
  end
end
