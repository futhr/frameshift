defmodule Frameshift.Transport.HTTPClientTest do
  use ExUnit.Case, async: false

  alias Frameshift.Transport.{HTTPClient, MTLSCredential, SPKIPin}
  alias Wotex.Binding.HTTP, as: WotexHTTP
  alias Wotex.Binding.HTTP.{Request, Response}
  alias Wotex.Runtime.{ConsumedThing, Context}
  alias Wotex.ThingDescription

  defmodule StaticCredentials do
    @moduledoc false
    @behaviour Wotex.Runtime.Credentials

    @impl Wotex.Runtime.Credentials
    def resolve(_security, _form, _context, credential), do: {:ok, credential}
  end

  defmodule FixtureResolver do
    @moduledoc false

    def resolve(_host, result), do: result
  end

  setup_all do
    {:ok, _applications} = Application.ensure_all_started(:ssl)

    subject_alt_name = {:Extension, {2, 5, 29, 17}, false, [dNSName: ~c"localhost"]}
    key = {:rsa, 2048, 65_537}

    data =
      :public_key.pkix_test_data(%{
        server_chain: %{
          root: [key: key],
          intermediates: [],
          peer: [key: key, extensions: [subject_alt_name]]
        },
        client_chain: %{root: [key: key], intermediates: [], peer: [key: key]}
      })

    certificate = Keyword.fetch!(data.server_config, :cert)
    decoded = :public_key.pkix_decode_cert(certificate, :otp)
    {:ok, fingerprint} = SPKIPin.fingerprint(decoded)

    {:ok,
     %{
       server: data.server_config,
       client: data.client_config,
       decoded_server_certificate: decoded,
       fingerprint: "sha256:" <> Base.encode16(fingerprint, case: :lower)
     }}
  end

  test "executes a bounded one-shot request over mutual TLS and a pinned server identity", pki do
    %{url: url, request: received} =
      serve_once(pki.server, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n42")

    request = request(url, max_response_bytes: 2)
    credential = credential(pki, origin(url))

    assert {:ok, response} = HTTPClient.request(request, credential, %{allow_loopback: true})
    assert Response.status(response) == 200
    assert Response.body(response) == "42"
    assert_receive {^received, bytes}
    assert bytes =~ "GET /state HTTP/1.1"
  end

  test "executes a selected TD Property through the pinned Wotex binding", pki do
    body = ~s({"displayState":"displayed","stateRevision":7})

    %{url: url, request: received} =
      serve_once(
        pki.server,
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" <>
          "Content-Length: #{byte_size(body)}\r\n\r\n#{body}"
      )

    {:ok, td} =
      ThingDescription.from_map(%{
        "@context" => Wotex.td_context_1_1(),
        "id" => "urn:frameshift:test:transport",
        "title" => "Transport test frame",
        "base" => origin(url) <> "/",
        "securityDefinitions" => %{
          "mtls" => %{"scheme" => "auto", "frameshift:mechanism" => "mutual-tls"}
        },
        "security" => ["mtls"],
        "properties" => %{
          "state" => %{
            "type" => "object",
            "readOnly" => true,
            "forms" => [
              %{
                "href" => "state",
                "contentType" => "application/json",
                "op" => "readproperty"
              }
            ]
          }
        }
      })

    {:ok, profile} = WotexHTTP.profile()

    {:ok, binding_config} =
      WotexHTTP.config(
        client: {HTTPClient, %{allow_loopback: true}},
        max_response_bytes: 4_096,
        max_header_count: 16,
        max_header_bytes: 4_096,
        max_uri_bytes: 1_024
      )

    {:ok, consumed} =
      ConsumedThing.new(td,
        profiles: [profile],
        transports: %{http: WotexHTTP.transport(binding_config)},
        credentials: {StaticCredentials, credential(pki, origin(url))}
      )

    context =
      Context.new!(
        request_id: "selected-property-test",
        deadline: System.monotonic_time(:millisecond) + 5_000
      )

    assert {:ok, result} = ConsumedThing.read_property(consumed, "state", context)
    assert result.payload == %{"displayState" => "displayed", "stateRevision" => 7}
    assert result.metadata.http.status == 200
    assert_receive {^received, bytes}
    assert bytes =~ "GET /state HTTP/1.1"
  end

  test "rejects a different server pin during the TLS handshake", pki do
    %{url: url} = serve_once(pki.server, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n42")

    wrong_fingerprint = "sha256:" <> String.duplicate("0", 64)
    credential = credential(pki, origin(url), wrong_fingerprint)

    assert {:error, :connection_failed} =
             HTTPClient.request(request(url), credential, %{allow_loopback: true})
  end

  test "rejects a request outside the credential authority before network I/O", pki do
    %{url: url} = serve_once(pki.server, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n42")
    credential = credential(pki, "https://different.local")

    assert {:error, :credential_audience_mismatch} =
             HTTPClient.request(request(url), credential, %{allow_loopback: true})
  end

  test "rejects non-local destinations before connecting", pki do
    credential = credential(pki, "https://8.8.8.8")

    assert {:error, :destination_forbidden} =
             HTTPClient.request(request("https://8.8.8.8/state"), credential, %{})
  end

  test "requires an absolute request deadline", pki do
    credential = credential(pki, "https://192.168.1.20")

    assert {:error, :deadline_required} =
             HTTPClient.request(
               request("https://192.168.1.20/state", deadline: nil),
               credential,
               %{}
             )
  end

  test "rejects expired deadlines, invalid resolver returns, and invalid callback arguments",
       pki do
    credential = credential(pki, "https://192.168.1.20")

    assert {:error, :timeout} =
             HTTPClient.request(
               request("https://192.168.1.20/state",
                 deadline: System.monotonic_time(:millisecond) - 1
               ),
               credential,
               %{}
             )

    assert {:error, :resolver_contract_violation} =
             HTTPClient.request(
               request("https://192.168.1.20/state"),
               credential,
               %{resolver: {FixtureResolver, :invalid}}
             )

    assert {:error, :invalid_client_arguments} = HTTPClient.request(:invalid, credential, %{})
  end

  test "rejects an oversized response from Content-Length before collecting its body", pki do
    %{url: url} =
      serve_once(
        pki.server,
        "HTTP/1.1 200 OK\r\nContent-Length: 1024\r\n\r\n" <> String.duplicate("x", 64)
      )

    assert {:error, :response_too_large} =
             HTTPClient.request(
               request(url, max_response_bytes: 8),
               credential(pki, origin(url)),
               %{allow_loopback: true}
             )
  end

  test "credential construction is strict and inspection redacts key material", pki do
    certificate = Keyword.fetch!(pki.client, :cert)
    private_key = Keyword.fetch!(pki.client, :key)

    assert {:error, :invalid_credential_origin} =
             MTLSCredential.new(
               "http://frame.local",
               pki.fingerprint,
               certificate,
               private_key
             )

    assert {:error, :invalid_server_fingerprint} =
             MTLSCredential.new(
               "https://frame.local",
               "sha256:not-a-pin",
               certificate,
               private_key
             )

    assert {:ok, credential} =
             MTLSCredential.new(
               "https://frame.local",
               pki.fingerprint,
               certificate,
               private_key
             )

    inspected = inspect(credential)
    assert inspected =~ "credentials=redacted"
    refute inspected =~ inspect(private_key)
    refute inspected =~ Base.encode64(certificate)
  end

  test "SPKI verification accepts only the pinned peer and safe path exceptions", pki do
    certificate = pki.decoded_server_certificate
    {:ok, expected} = SPKIPin.fingerprint(certificate)
    state = %{expected: expected}

    assert {:valid, ^state} = SPKIPin.verify(certificate, {:bad_cert, :unknown_ca}, state)
    assert {:valid, ^state} = SPKIPin.verify(certificate, :valid, state)
    assert {:unknown, ^state} = SPKIPin.verify(certificate, {:extension, :unknown}, state)

    assert {:fail, {:bad_cert, :cert_expired}} =
             SPKIPin.verify(certificate, {:bad_cert, :cert_expired}, state)

    assert {:valid, %{matched: true}} = SPKIPin.verify(certificate, :valid_peer, state)

    assert {:fail, :server_spki_mismatch} =
             SPKIPin.verify(certificate, :valid_peer, %{expected: <<0::256>>})

    assert {:error, :invalid_certificate} = SPKIPin.fingerprint({})
    assert {:error, :invalid_certificate} = SPKIPin.fingerprint(:invalid)
  end

  defp request(url, options \\ []) do
    deadline = Keyword.get(options, :deadline, System.monotonic_time(:millisecond) + 5_000)

    {:ok, request} =
      Request.new("GET", url, [], nil,
        request_id: "http-client-test",
        deadline: deadline,
        operation: :readproperty,
        media_type: "application/json",
        stream?: false,
        max_response_bytes: Keyword.get(options, :max_response_bytes, 4_096),
        max_event_bytes: 4_096,
        max_header_count: 16,
        max_header_bytes: 4_096,
        max_uri_bytes: 1_024
      )

    request
  end

  defp credential(pki, origin, fingerprint \\ nil) do
    {:ok, credential} =
      MTLSCredential.new(
        origin,
        fingerprint || pki.fingerprint,
        Keyword.fetch!(pki.client, :cert),
        Keyword.fetch!(pki.client, :key)
      )

    credential
  end

  defp origin(url) do
    uri = URI.parse(url)
    "https://#{uri.host}:#{uri.port}"
  end

  defp serve_once(server_config, response) do
    options =
      server_config ++
        [
          active: false,
          mode: :binary,
          reuseaddr: true,
          verify: :verify_peer,
          fail_if_no_peer_cert: true
        ]

    {:ok, listener} = :ssl.listen(0, options)
    {:ok, {_, port}} = :ssl.sockname(listener)
    owner = self()
    request_message = make_ref()

    pid =
      spawn(fn ->
        result =
          with {:ok, transport} <- :ssl.transport_accept(listener, 5_000),
               {:ok, socket} <- :ssl.handshake(transport, 5_000),
               {:ok, request_bytes} <- receive_headers(socket, <<>>),
               :ok <- :ssl.send(socket, response) do
            send(owner, {request_message, request_bytes})
            :ssl.close(socket)
          end

        send(owner, {:server_finished, request_message, result})
        :ssl.close(listener)
      end)

    on_exit(fn ->
      :ssl.close(listener)
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    %{url: "https://localhost:#{port}/state", request: request_message}
  end

  defp receive_headers(socket, bytes) do
    if String.contains?(bytes, "\r\n\r\n") do
      {:ok, bytes}
    else
      with {:ok, more} <- :ssl.recv(socket, 0, 5_000),
           do: receive_headers(socket, bytes <> more)
    end
  end
end
