defmodule Frameshift.Outbox.ServiceTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Frameshift.Library
  alias Frameshift.Outbox.Service
  alias Frameshift.Transport.SPKIPin

  @thing_fixture Path.expand(
                   "../../../../../protocol/fixtures/valid/thing-description.json",
                   __DIR__
                 )

  defmodule Resolver do
    @moduledoc false

    @spec resolve(String.t(), map()) :: {:ok, map()} | {:error, atom()}
    def resolve(reference, %{reference: reference, identity: identity}), do: {:ok, identity}
    def resolve(_, _), do: {:error, :identity_mismatch}
  end

  @tag :requires_socket
  test "the listener follows paired pull custody and serves only an admitted frame" do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-outbox-service-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, library} = Library.start_link(data_dir: Path.join(root, "library"), name: nil)
    on_exit(fn -> stop_if_alive(library) end)
    {:ok, workers} = Task.Supervisor.start_link(max_children: 17)
    on_exit(fn -> stop_if_alive(workers) end)

    key = {:rsa, 2048, 65_537}

    certificates =
      :public_key.pkix_test_data(%{
        server_chain: %{root: [key: key], intermediates: [], peer: [key: key]},
        client_chain: %{root: [key: key], intermediates: [], peer: [key: key]}
      })

    frame_certificate = Keyword.fetch!(certificates.client_config, :cert)
    {:ok, frame_pin} = SPKIPin.fingerprint_der(frame_certificate)
    server_certificate = Keyword.fetch!(certificates.server_config, :cert)
    {:ok, server_pin} = SPKIPin.fingerprint_der(server_certificate)
    reference = "keychain:outbox-service-test"

    {:ok, service} =
      Service.start_link(
        name: nil,
        library: library,
        task_supervisor: workers,
        bind_address: {127, 0, 0, 1},
        resolver:
          {Resolver,
           %{
             reference: reference,
             identity: %{
               certificate: server_certificate,
               private_key: Keyword.fetch!(certificates.server_config, :key)
             }
           }}
      )

    on_exit(fn -> stop_if_alive(service) end)
    assert %{available: false, port: nil} = Service.status(service)

    assert {:ok, _} =
             Library.register_paired_frame(
               library,
               File.read!(@thing_fixture),
               reference,
               frame_pin
             )

    assert :ok = Service.refresh(service)
    assert %{available: true, port: port} = await_available(service)
    assert port in 1..65_535

    assert {:ok, socket} =
             :ssl.connect(
               ~c"127.0.0.1",
               port,
               [
                 active: false,
                 mode: :binary,
                 verify: :verify_peer,
                 cacerts: [],
                 cert: frame_certificate,
                 key: Keyword.fetch!(certificates.client_config, :key),
                 verify_fun: {&SPKIPin.verify/3, %{expected: server_pin}},
                 versions: [:"tlsv1.3"],
                 server_name_indication: :disable
               ],
               5_000
             )

    assert :ok = :ssl.send(socket, "GET /v0/outbox/manifest HTTP/1.1\r\nHost: host.local\r\n\r\n")
    assert {:ok, response} = :ssl.recv(socket, 0, 5_000)
    assert response =~ "HTTP/1.1 204 No Content"
    :ssl.close(socket)

    other_thing =
      File.read!(@thing_fixture)
      |> String.replace("sim-photo-00000001", "sim-photo-00000002")

    assert {:ok, _} =
             Library.register_paired_frame(
               library,
               other_thing,
               "keychain:other-host-identity",
               "sha256:" <> String.duplicate("c", 64)
             )

    assert :ok = Service.refresh(service)
    assert %{available: false, port: nil} = await_unavailable(service)
    assert :ok = Library.forget_paired_frame(library, "sim-photo-00000002")
    assert :ok = Service.refresh(service)
    assert %{available: true} = await_available(service)

    assert :ok = Library.forget_paired_frame(library, "sim-photo-00000001")
    assert :ok = Service.refresh(service)
    assert %{available: false, port: nil} = await_unavailable(service)
  end

  defp await_available(service, attempts \\ 100)
  defp await_available(service, 0), do: Service.status(service)

  defp await_available(service, attempts) do
    case Service.status(service) do
      %{available: true} = status ->
        status

      _ ->
        Process.sleep(10)
        await_available(service, attempts - 1)
    end
  end

  defp await_unavailable(service, attempts \\ 100)
  defp await_unavailable(service, 0), do: Service.status(service)

  defp await_unavailable(service, attempts) do
    case Service.status(service) do
      %{available: false} = status ->
        status

      _ ->
        Process.sleep(10)
        await_unavailable(service, attempts - 1)
    end
  end

  defp stop_if_alive(process) do
    if Process.alive?(process), do: GenServer.stop(process)
  catch
    :exit, _ -> :ok
  end
end
