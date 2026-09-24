defmodule Frameshift.Pairing.TLSServerTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Frameshift.Pairing.{HTTP1, TLSServer}
  alias Frameshift.Simulator
  alias Frameshift.Transport.SPKIPin

  @device_id "frame-000000000001"
  @secret <<10::128>>

  setup_all do
    key = {:rsa, 2048, 65_537}

    certificates =
      :public_key.pkix_test_data(%{
        server_chain: %{root: [key: key], intermediates: [], peer: [key: key]},
        client_chain: %{root: [key: key], intermediates: [], peer: [key: key]}
      })

    server_certificate = Keyword.fetch!(certificates.server_config, :cert)
    {:ok, server_pin} = SPKIPin.fingerprint_der(server_certificate)

    %{
      server_config: certificates.server_config,
      client_config: certificates.client_config,
      server_pin: server_pin
    }
  end

  test "invalid bind addresses are rejected before a socket is opened", context do
    Process.flag(:trap_exit, true)

    assert {:error, :invalid_listener_options} =
             TLSServer.start_link(
               name: nil,
               frame: self(),
               task_supervisor: self(),
               bind_address: {256, 0, 0, 1},
               port: 0,
               certificate: Keyword.fetch!(context.server_config, :cert),
               private_key: Keyword.fetch!(context.server_config, :key)
             )
  end

  test "commissioning accepts an untrusted client chain but rejects other certificate errors" do
    assert {:valid, :state} =
             TLSServer.verify_client(:certificate, {:bad_cert, :unknown_ca}, :state)

    assert {:fail, {:bad_cert, :cert_expired}} =
             TLSServer.verify_client(:certificate, {:bad_cert, :cert_expired}, :state)
  end

  @tag :requires_socket
  test "a TLS-authenticated host pairs through the fixed route", context do
    data_dir =
      Path.join(
        System.tmp_dir!(),
        "frameshift-pairing-tls-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(data_dir) end)

    capabilities =
      Path.expand("../../../../../protocol/fixtures/valid/capabilities-photo.json", __DIR__)
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("deviceId", @device_id)

    thing_source =
      Path.expand("../../../../../protocol/fixtures/valid/thing-description.json", __DIR__)
      |> File.read!()
      |> String.replace("sim-photo-00000001", @device_id)

    {:ok, frame} =
      Simulator.start_link(
        data_dir: data_dir,
        capabilities: capabilities,
        thing_source: thing_source,
        pairing_secret: @secret,
        name: nil
      )

    on_exit(fn -> stop_if_alive(frame) end)
    assert :ok = Simulator.open_pairing(frame, System.system_time(:millisecond))

    {:ok, workers} = Task.Supervisor.start_link(max_children: 17)
    on_exit(fn -> stop_if_alive(workers) end)

    assert {:ok, server} =
             TLSServer.start_link(
               name: nil,
               frame: frame,
               task_supervisor: workers,
               bind_address: {127, 0, 0, 1},
               port: 0,
               certificate: Keyword.fetch!(context.server_config, :cert),
               private_key: Keyword.fetch!(context.server_config, :key)
             )

    on_exit(fn -> stop_if_alive(server) end)
    assert {:ok, port} = TLSServer.port(server)

    introduction = "GET /.well-known/wot HTTP/1.1\r\nHost: frame.local\r\n\r\n"

    assert {:ok, before_pair} =
             HTTP1.exchange(frame, Keyword.fetch!(context.client_config, :cert), introduction, 0)

    assert before_pair =~ "HTTP/1.1 404 Not Found\r\n"

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

    body =
      RFC8785.encode!(%{
        "version" => 1,
        "requestId" => "pair-1",
        "deviceId" => @device_id,
        "secret" => Base.url_encode64(@secret, padding: false)
      })

    wire =
      "POST /.well-known/frameshift/pair HTTP/1.1\r\n" <>
        "Host: frame.local\r\n" <>
        "Content-Type: application/json\r\n" <>
        "Content-Length: #{byte_size(body)}\r\n\r\n" <> body

    assert :ok = :ssl.send(socket, wire)
    assert {:ok, response} = recv_until_close(socket, <<>>)
    assert response =~ "HTTP/1.1 201 Created\r\n"
    assert response =~ "\"requestId\":\"pair-1\""

    assert {:ok, admitted_thing} =
             HTTP1.exchange(
               frame,
               Keyword.fetch!(context.client_config, :cert),
               introduction,
               0
             )

    assert admitted_thing =~ "HTTP/1.1 200 OK\r\n"
    [_, admitted_body] = String.split(admitted_thing, "\r\n\r\n", parts: 2)

    assert get_in(Jason.decode!(admitted_body), ["frameshift:capabilities", "deviceId"]) ==
             @device_id

    assert {:ok, refused_thing} = HTTP1.exchange(frame, <<1, 2, 3>>, introduction, 0)
    assert refused_thing =~ "HTTP/1.1 404 Not Found\r\n"
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
