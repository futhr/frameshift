defmodule Frameshift.Pairing.ClientTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Pairing.{Bootstrap, Client, Endpoint, HTTP1, Window}
  alias Frameshift.Simulator
  alias Frameshift.Transport.{MTLSCredential, SPKIPin}
  alias Wotex.Binding.HTTP.{Request, Response}

  @device_id "frame-000000000001"
  @secret :binary.copy(<<1, 2, 3, 4>>, 4)

  setup_all do
    key = {:rsa, 2048, 65_537}

    certificates =
      :public_key.pkix_test_data(%{
        server_chain: %{root: [key: key], intermediates: [], peer: [key: key]},
        client_chain: %{root: [key: key], intermediates: [], peer: [key: key]}
      })

    frame_certificate = Keyword.fetch!(certificates.server_config, :cert)
    assert {:ok, frame_pin} = SPKIPin.fingerprint_der(frame_certificate)

    %{
      frame_pin: frame_pin,
      host_certificate: Keyword.fetch!(certificates.client_config, :cert),
      host_key: Keyword.fetch!(certificates.client_config, :key)
    }
  end

  test "sends the secret only to the QR-pinned origin and validates the frame receipt", context do
    bootstrap = bootstrap(context.frame_pin)

    {:ok, credential} =
      MTLSCredential.new(
        "https://frame.local",
        context.frame_pin,
        context.host_certificate,
        context.host_key
      )

    {:ok, window} = Window.new(@device_id, @secret)
    {:ok, opened} = Window.open(window, 100)
    owner = self()

    transport = fn request, supplied_credential ->
      send(owner, {:pairing_request, request, supplied_credential})

      {result, _next} =
        Endpoint.handle(opened, context.host_certificate, Request.body(request), 101)

      Response.new(result.status, [{"content-type", result.content_type}], result.body)
    end

    assert {:ok, receipt} = Client.pair(bootstrap, credential, "pair-1", transport: transport)
    assert receipt.device_id == @device_id
    assert receipt.request_id == "pair-1"

    assert_receive {:pairing_request, request, ^credential}
    assert Request.method(request) == "POST"
    assert Request.uri(request) == "https://frame.local/.well-known/frameshift/pair"

    body = Jason.decode!(Request.body(request))
    assert body["secret"] == Base.url_encode64(@secret, padding: false)
    refute Map.has_key?(body, "hostCertificate")
  end

  test "a pin mismatch rejects before any transport or secret transmission", context do
    bootstrap = bootstrap("sha256:" <> String.duplicate("0", 64))

    {:ok, credential} =
      MTLSCredential.new(
        "https://frame.local",
        context.frame_pin,
        context.host_certificate,
        context.host_key
      )

    transport = fn _request, _credential -> flunk("transport must not run") end

    assert {:error, :peer_identity_mismatch} =
             Client.pair(bootstrap, credential, "pair-1", transport: transport)
  end

  test "host client and frame HTTP binding agree on the authenticated wire exchange", context do
    data_dir =
      Path.join(
        System.tmp_dir!(),
        "frameshift-pairing-client-wire-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(data_dir) end)

    capabilities =
      Path.expand("../../../../../protocol/fixtures/valid/capabilities-photo.json", __DIR__)
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("deviceId", @device_id)

    {:ok, frame} =
      Simulator.start_link(
        data_dir: data_dir,
        capabilities: capabilities,
        pairing_secret: @secret,
        name: nil
      )

    on_exit(fn -> if Process.alive?(frame), do: GenServer.stop(frame) end)
    assert :ok = Simulator.open_pairing(frame, 100)

    {:ok, credential} =
      MTLSCredential.new(
        "https://frame.local",
        context.frame_pin,
        context.host_certificate,
        context.host_key
      )

    transport = fn request, _credential ->
      body = Request.body(request)

      wire =
        "POST /.well-known/frameshift/pair HTTP/1.1\r\n" <>
          "Host: frame.local\r\n" <>
          "Content-Type: application/json\r\n" <>
          "Content-Length: #{byte_size(body)}\r\n\r\n" <> body

      {:ok, response_wire} = HTTP1.exchange(frame, context.host_certificate, wire, 101)
      [head, response_body] = :binary.split(response_wire, "\r\n\r\n")
      [status_line | headers] = :binary.split(head, "\r\n", [:global])
      <<"HTTP/1.1 ", status_text::binary-size(3), _rest::binary>> = status_line

      response_headers =
        Enum.map(headers, fn line ->
          [name, value] = :binary.split(line, ": ")
          {name, value}
        end)

      Response.new(String.to_integer(status_text), response_headers, response_body)
    end

    assert {:ok, receipt} =
             Client.pair(bootstrap(context.frame_pin), credential, "pair-1", transport: transport)

    assert receipt.device_id == @device_id
  end

  test "rejects a mismatched host identity or response media type", context do
    bootstrap = bootstrap(context.frame_pin)

    {:ok, credential} =
      MTLSCredential.new(
        "https://frame.local",
        context.frame_pin,
        context.host_certificate,
        context.host_key
      )

    forged =
      RFC8785.encode!(%{
        "version" => 1,
        "requestId" => "pair-1",
        "deviceId" => @device_id,
        "hostCertificateFingerprint" => "sha256:" <> String.duplicate("0", 64)
      })

    wrong_identity = fn _request, _credential ->
      Response.new(201, [{"content-type", "application/json"}], forged)
    end

    wrong_media_type = fn _request, _credential ->
      Response.new(201, [{"content-type", "text/plain"}], forged)
    end

    assert {:error, :invalid_pairing_response} =
             Client.pair(bootstrap, credential, "pair-1", transport: wrong_identity)

    assert {:error, :invalid_pairing_response} =
             Client.pair(bootstrap, credential, "pair-1", transport: wrong_media_type)
  end

  test "invalid requests and transport failures never return a pairing receipt", context do
    {:ok, credential} =
      MTLSCredential.new(
        "https://frame.local",
        context.frame_pin,
        context.host_certificate,
        context.host_key
      )

    bootstrap = bootstrap(context.frame_pin)
    never_send = fn _request, _credential -> flunk("transport must not run") end

    assert {:error, :invalid_pairing_request} = Client.pair(nil, credential, "pair-1")

    assert {:error, :invalid_pairing_request} =
             Client.pair(bootstrap, credential, "bad id", transport: never_send)

    assert {:error, :pairing_rejected} =
             Client.pair(bootstrap, credential, "pair-1",
               transport: fn _request, _credential -> Response.new(403, [], "") end
             )

    assert {:error, :pairing_transport_failure} =
             Client.pair(bootstrap, credential, "pair-1",
               transport: fn _request, _credential -> raise "transport failed" end
             )

    assert {:error, :invalid_pairing_response} =
             Client.pair(bootstrap, credential, "pair-1",
               transport: fn _request, _credential ->
                 Response.new(201, [{"content-type", "application/json"}], "{")
               end
             )
  end

  defp bootstrap(pin) do
    {:ok, bootstrap} =
      Bootstrap.parse(
        Jason.encode!(%{
          version: 1,
          deviceId: @device_id,
          serverSpki: pin,
          secret: Base.url_encode64(@secret, padding: false)
        })
      )

    bootstrap
  end
end
