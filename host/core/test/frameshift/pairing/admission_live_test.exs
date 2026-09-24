defmodule Frameshift.Pairing.AdmissionLiveTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Frameshift.Library
  alias Frameshift.Pairing.{Admission, TLSServer}
  alias Frameshift.Simulator
  alias Frameshift.Transport.SPKIPin

  @device_id "sim-photo-00000001"
  @secret :binary.copy(<<19, 43, 71, 101>>, 4)

  defmodule Resolver do
    @moduledoc false

    @spec resolve(String.t(), map()) :: {:ok, map()}
    def resolve(_, identity), do: {:ok, identity}
  end

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
      certificates: certificates,
      server_pin: server_pin
    }
  end

  @tag :requires_socket
  test "one live mutual-TLS pair is followed by authenticated TD admission", context do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-pair-live-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, library} = Library.start_link(data_dir: Path.join(root, "library"), name: nil)
    on_exit(fn -> stop_if_alive(library) end)

    capabilities =
      Path.expand("../../../../../protocol/fixtures/valid/capabilities-photo.json", __DIR__)
      |> File.read!()
      |> Jason.decode!()

    {:ok, frame} =
      Simulator.start_link(
        data_dir: Path.join(root, "frame"),
        capabilities: capabilities,
        pairing_secret: @secret,
        name: nil
      )

    on_exit(fn -> stop_if_alive(frame) end)
    {:ok, workers} = Task.Supervisor.start_link(max_children: 17)
    on_exit(fn -> stop_if_alive(workers) end)

    assert {:ok, listener} =
             TLSServer.start_link(
               name: nil,
               frame: frame,
               task_supervisor: workers,
               bind_address: {127, 0, 0, 1},
               port: 0,
               certificate: Keyword.fetch!(context.certificates.server_config, :cert),
               private_key: Keyword.fetch!(context.certificates.server_config, :key)
             )

    on_exit(fn -> stop_if_alive(listener) end)
    assert {:ok, port} = TLSServer.port(listener)
    origin = "https://127.0.0.1:#{port}"

    thing_source =
      Path.expand("../../../../../protocol/fixtures/valid/thing-description.json", __DIR__)
      |> File.read!()
      |> String.replace("https://frame.invalid/", origin <> "/")

    assert :ok = Simulator.set_thing_source(frame, thing_source)
    assert :ok = Simulator.open_pairing(frame, System.system_time(:millisecond))

    bootstrap =
      RFC8785.encode!(%{
        "version" => 1,
        "deviceId" => @device_id,
        "serverSpki" => context.server_pin,
        "secret" => Base.url_encode64(@secret, padding: false)
      })

    client_identity = %{
      certificate: Keyword.fetch!(context.certificates.client_config, :cert),
      private_key: Keyword.fetch!(context.certificates.client_config, :key)
    }

    assert {:ok, %{"frameId" => @device_id}} =
             Admission.pair(
               bootstrap,
               @device_id,
               origin,
               "keychain:live-pair-test",
               "live-pair-1",
               library: library,
               resolver: {Resolver, client_identity},
               transport_config: %{allow_loopback: true}
             )

    assert {:ok, paired} = Library.get_paired_frame(library, @device_id)
    assert paired["server_spki_fingerprint"] == context.server_pin
    assert paired["credential_ref"] == "keychain:live-pair-test"
  end

  defp stop_if_alive(process) do
    if Process.alive?(process), do: GenServer.stop(process)
  catch
    :exit, _ -> :ok
  end
end
