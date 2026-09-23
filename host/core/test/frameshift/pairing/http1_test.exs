defmodule Frameshift.Pairing.HTTP1Test do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Pairing.HTTP1
  alias Frameshift.Simulator

  @device_id "frame-000000000001"
  @secret <<9::128>>

  setup do
    data_dir =
      Path.join(
        System.tmp_dir!(),
        "frameshift-pairing-http-#{System.unique_integer([:positive, :monotonic])}"
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

    key = {:rsa, 2048, 65_537}

    certificates =
      :public_key.pkix_test_data(%{
        server_chain: %{root: [key: key], intermediates: [], peer: [key: key]},
        client_chain: %{root: [key: key], intermediates: [], peer: [key: key]}
      })

    %{frame: frame, peer: Keyword.fetch!(certificates.client_config, :cert)}
  end

  test "only the fixed route can consume a physical pairing window", %{frame: frame, peer: peer} do
    body = request_body()
    assert :ok = Simulator.open_pairing(frame, 100)

    assert {:ok, not_found} = HTTP1.exchange(frame, peer, wire("/other", body), 101)
    assert not_found =~ "HTTP/1.1 404 Not Found\r\n"

    assert {:ok, created} =
             HTTP1.exchange(frame, peer, wire("/.well-known/frameshift/pair", body), 102)

    assert created =~ "HTTP/1.1 201 Created\r\n"
    assert created =~ "\"requestId\":\"pair-1\""

    assert {:ok, replay} =
             HTTP1.exchange(frame, peer, wire("/.well-known/frameshift/pair", body), 103)

    assert replay =~ "HTTP/1.1 200 OK\r\n"
  end

  test "wire framing is incremental and bounded", %{frame: frame, peer: peer} do
    wire = wire("/.well-known/frameshift/pair", request_body())
    assert :more = HTTP1.exchange(frame, peer, binary_part(wire, 0, byte_size(wire) - 1), 100)

    assert {:ok, rejected} = HTTP1.exchange(frame, peer, :binary.copy("x", 8_193), 100)
    assert rejected =~ "HTTP/1.1 413 Content Too Large\r\n"

    smuggled = wire <> "GET / HTTP/1.1\r\nHost: x\r\n\r\n"
    assert {:ok, invalid} = HTTP1.exchange(frame, peer, smuggled, 100)
    assert invalid =~ "HTTP/1.1 400 Bad Request\r\n"
  end

  test "a network request cannot open pair mode", %{frame: frame, peer: peer} do
    assert {:ok, rejected} =
             HTTP1.exchange(
               frame,
               peer,
               wire("/.well-known/frameshift/pair", request_body()),
               100
             )

    assert rejected =~ "HTTP/1.1 403 Forbidden\r\n"
    assert rejected =~ "urn:frameshift:problem:pair-mode-required"
  end

  test "oversized bodies and malformed framing cannot consume pair mode", %{
    frame: frame,
    peer: peer
  } do
    assert :ok = Simulator.open_pairing(frame, 100)

    assert {:ok, too_large} =
             HTTP1.exchange(
               frame,
               peer,
               wire("/.well-known/frameshift/pair", :binary.copy("x", 2_049)),
               101
             )

    assert too_large =~ "HTTP/1.1 413 Content Too Large\r\n"

    assert {:ok, malformed} = HTTP1.exchange(frame, peer, "POST / HTTP/1.1\r\nBad\r\n\r\n", 102)
    assert malformed =~ "HTTP/1.1 400 Bad Request\r\n"

    assert {:ok, created} =
             HTTP1.exchange(
               frame,
               peer,
               wire("/.well-known/frameshift/pair", request_body()),
               103
             )

    assert created =~ "HTTP/1.1 201 Created\r\n"
  end

  defp request_body do
    Jason.encode!(%{
      version: 1,
      requestId: "pair-1",
      deviceId: @device_id,
      secret: Base.url_encode64(@secret, padding: false)
    })
  end

  defp wire(path, body) do
    "POST #{path} HTTP/1.1\r\n" <>
      "Host: frame.local\r\n" <>
      "Content-Type: application/json\r\n" <>
      "Content-Length: #{byte_size(body)}\r\n\r\n" <> body
  end
end
