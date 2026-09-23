defmodule Frameshift.Outbox.TLSServerTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Frameshift.Library
  alias Frameshift.Outbox.TLSServer
  alias Frameshift.Transport.SPKIPin

  @thing_fixture Path.expand(
                   "../../../../../protocol/fixtures/valid/thing-description.json",
                   __DIR__
                 )

  setup_all do
    key = {:rsa, 2048, 65_537}

    certificates =
      :public_key.pkix_test_data(%{
        server_chain: %{root: [key: key], intermediates: [], peer: [key: key]},
        client_chain: %{root: [key: key], intermediates: [], peer: [key: key]}
      })

    server_cert = Keyword.fetch!(certificates.server_config, :cert)
    frame_cert = Keyword.fetch!(certificates.client_config, :cert)
    {:ok, server_pin} = SPKIPin.fingerprint(:public_key.pkix_decode_cert(server_cert, :otp))
    {:ok, frame_pin} = SPKIPin.fingerprint_der(frame_cert)

    %{
      server_config: certificates.server_config,
      client_config: certificates.client_config,
      server_pin: server_pin,
      frame_pin: frame_pin
    }
  end

  test "rejects invalid bind addresses before opening a socket", context do
    Process.flag(:trap_exit, true)

    assert {:error, :invalid_listener_options} =
             TLSServer.start_link(
               name: nil,
               library: self(),
               task_supervisor: self(),
               bind_address: {256, 0, 0, 1},
               port: 0,
               certificate: Keyword.fetch!(context.server_config, :cert),
               private_key: Keyword.fetch!(context.server_config, :key)
             )
  end

  @tag :requires_socket
  test "one paired frame reads its empty outbox over a pinned mutual-TLS socket", context do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-outbox-tls-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, library} = Library.start_link(data_dir: Path.join(root, "library"), name: nil)
    on_exit(fn -> stop_if_alive(library) end)

    assert {:ok, _} =
             Library.register_paired_frame(
               library,
               File.read!(@thing_fixture),
               "keychain:tls-outbox-test-frame",
               context.frame_pin
             )

    {:ok, workers} = Task.Supervisor.start_link(max_children: 17)
    on_exit(fn -> stop_if_alive(workers) end)

    assert {:ok, server} =
             TLSServer.start_link(
               name: nil,
               library: library,
               task_supervisor: workers,
               bind_address: {127, 0, 0, 1},
               port: 0,
               certificate: Keyword.fetch!(context.server_config, :cert),
               private_key: Keyword.fetch!(context.server_config, :key)
             )

    on_exit(fn -> stop_if_alive(server) end)
    assert {:ok, port} = TLSServer.port(server)

    assert {:ok, socket} =
             :ssl.connect(
               ~c"127.0.0.1",
               port,
               [
                 active: false,
                 mode: :binary,
                 verify: :verify_peer,
                 cacerts: [],
                 cert: Keyword.fetch!(context.client_config, :cert),
                 key: Keyword.fetch!(context.client_config, :key),
                 verify_fun: {&SPKIPin.verify/3, %{expected: context.server_pin}},
                 versions: [:"tlsv1.3"],
                 alpn_advertised_protocols: ["http/1.1"],
                 server_name_indication: :disable
               ],
               5_000
             )

    assert :ok =
             :ssl.send(
               socket,
               "GET /v0/outbox/manifest HTTP/1.1\r\nHost: host.local\r\n\r\n"
             )

    assert {:ok, response} = recv_until_close(socket, <<>>)
    assert response =~ "HTTP/1.1 204 No Content\r\n"
    assert response =~ "content-length: 0\r\n"
    assert response =~ "connection: close\r\n"
    :ssl.close(socket)
  end

  defp recv_until_close(socket, bytes) do
    case :ssl.recv(socket, 0, 5_000) do
      {:ok, more} -> recv_until_close(socket, bytes <> more)
      {:error, :closed} -> {:ok, bytes}
      {:error, reason} -> {:error, reason}
    end
  end

  defp stop_if_alive(process) do
    if Process.alive?(process), do: GenServer.stop(process)
  catch
    :exit, _ -> :ok
  end
end
