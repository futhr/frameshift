defmodule Frameshift.Outbox.HTTP1Test do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Outbox.HTTP1

  test "accepts one exact, incrementally received outbox request" do
    wire =
      "POST /v0/outbox/ack HTTP/1.1\r\n" <>
        "Host: host.local\r\n" <>
        "Content-Type: application/json\r\n" <>
        "Content-Length: 2\r\n\r\n{}"

    for cut <- 1..(byte_size(wire) - 1) do
      assert :more = HTTP1.decode(binary_part(wire, 0, cut))
    end

    assert {:ok,
            %{
              method: "POST",
              path: "/v0/outbox/ack",
              content_type: "application/json",
              body: "{}"
            }} = HTTP1.decode(wire)
  end

  test "rejects framing ambiguity, request smuggling, and pipelining" do
    base = "POST /v0/outbox/ack HTTP/1.1\r\nHost: host.local\r\n"

    invalid = [
      base <> "Content-Length: 2\r\nContent-Length: 2\r\nContent-Type: application/json\r\n\r\n{}",
      base <> "Transfer-Encoding: chunked\r\nContent-Type: application/json\r\n\r\n0\r\n\r\n",
      base <> "Content-Length: 2\r\nContent-Type: application/json\r\n\r\n{}GET /",
      base <> "Content-Length: -1\r\nContent-Type: application/json\r\n\r\n",
      base <> "Content-Length: 02\r\nContent-Type: application/json\r\n\r\n{}",
      base <> "Content-Length: 2\r\nContent-Type: application/json\r\n Folded: x\r\n\r\n{}",
      base <>
        "Content-Length: 2\r\nContent-Type: application/json\r\nX-Invalid: \tsecret\r\n\r\n{}",
      "GET /v0/outbox/manifest HTTP/1.1\r\nHost: host.local\r\nContent-Length: 1\r\n\r\nx",
      "GET /v0/outbox/manifest HTTP/1.1\r\nHost: host.local\r\n\r\nx"
    ]

    for wire <- invalid do
      assert {:error, :invalid_request} = HTTP1.decode(wire)
    end
  end

  test "rejects oversized headers, body declarations, and request targets" do
    assert {:error, :request_too_large} = HTTP1.decode(:binary.copy("x", 65_537))

    assert {:error, :request_too_large} =
             HTTP1.decode(
               "POST /v0/outbox/ack HTTP/1.1\r\nHost: host.local\r\n" <>
                 "Content-Type: application/json\r\nContent-Length: 65537\r\n\r\n"
             )

    assert {:error, :invalid_request} =
             HTTP1.decode(
               "GET /#{String.duplicate("x", 1_024)} HTTP/1.1\r\nHost: host.local\r\n\r\n"
             )
  end

  test "rejects non-origin targets and non-ASCII header names before string processing" do
    assert {:error, :invalid_request} =
             HTTP1.decode(
               "GET https://host.local/v0/outbox/manifest HTTP/1.1\r\nHost: host.local\r\n\r\n"
             )

    assert {:error, :invalid_request} =
             HTTP1.decode(
               "GET /v0/outbox/manifest HTTP/1.1\r\nHost: host.local\r\nX-" <>
                 <<255>> <> ": value\r\n\r\n"
             )
  end
end
