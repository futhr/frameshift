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

  test "completed exchanges emit bounded route and outcome telemetry" do
    handler_id = {__MODULE__, self()}

    :ok =
      :telemetry.attach(
        handler_id,
        [:frameshift, :outbox, :exchange],
        &__MODULE__.capture_event/4,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    assert {:ok, response} =
             HTTP1.exchange(
               nil,
               <<>>,
               "GET /secret?token=value HTTP/1.1\r\nHost: host.local\r\n\r\n"
             )

    assert response =~ "HTTP/1.1 400 Bad Request"

    assert_receive {[:frameshift, :outbox, :exchange], measurements, metadata}
    assert measurements.count == 1
    assert is_integer(measurements.duration_ms)
    assert metadata == %{route: :invalid, outcome: :rejected}

    assert {:ok, denied} =
             HTTP1.exchange(
               nil,
               <<>>,
               "GET /v0/outbox/manifest HTTP/1.1\r\nHost: host.local\r\n\r\n"
             )

    assert denied =~ "HTTP/1.1 403 Forbidden"
    assert_receive {[:frameshift, :outbox, :exchange], _, %{route: :manifest, outcome: :rejected}}

    assert :more = HTTP1.exchange(nil, <<>>, "GET /v0/outbox/manifest HTTP/1.1\r\n")
    refute_receive {[:frameshift, :outbox, :exchange], _, _}
  end

  @doc false
  @spec capture_event(list(atom()), map(), map(), pid()) :: term()
  def capture_event(event, measurements, metadata, owner),
    do: send(owner, {event, measurements, metadata})
end
