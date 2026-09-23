defmodule Frameshift.Pairing.HTTP1 do
  @moduledoc """
  Serves the fixed pre-pair route over one bounded HTTP/1.1 exchange.

  Framing comes from the shared strict parser. Only the authenticated TLS
  peer certificate supplied by the listener can authorize a host; neither
  headers nor JSON can supply that identity. Pair mode itself is opened only
  through the frame's physical adapter.
  """

  alias Frameshift.Outbox.HTTP1, as: RequestParser
  alias Frameshift.Simulator

  @path "/.well-known/frameshift/pair"
  @maximum_wire_bytes 8_192
  @maximum_body_bytes 2_048

  @doc "Returns the pairing binding's maximum complete wire request size."
  @spec maximum_wire_bytes() :: pos_integer()
  def maximum_wire_bytes, do: @maximum_wire_bytes

  @doc "Consumes one complete request or asks the TLS reader for more bytes."
  @spec exchange(GenServer.server(), binary(), binary(), non_neg_integer()) ::
          {:ok, binary()} | :more
  def exchange(_frame, _peer_der, wire, _now_ms) when byte_size(wire) > @maximum_wire_bytes,
    do: error(413, "request-too-large", "Request too large")

  def exchange(frame, peer_der, wire, now_ms),
    do: respond(RequestParser.decode(wire), frame, peer_der, now_ms, byte_size(wire))

  defp respond(
         {:ok, %{method: "POST", path: @path, content_type: "application/json", body: body}},
         frame,
         peer_der,
         now_ms,
         _wire_size
       )
       when byte_size(body) <= @maximum_body_bytes do
    case Simulator.pair(frame, peer_der, body, now_ms) do
      {:ok, response} -> {:ok, encode(response)}
      {:error, _reason} -> error(503, "pairing-unavailable", "Pairing unavailable")
    end
  end

  defp respond({:ok, %{body: body}}, _frame, _peer_der, _now_ms, _wire_size)
       when byte_size(body) > @maximum_body_bytes,
       do: error(413, "request-too-large", "Request too large")

  defp respond({:ok, _request}, _frame, _peer_der, _now_ms, _wire_size),
    do: error(404, "not-found", "Resource not found")

  defp respond({:error, :request_too_large}, _frame, _peer_der, _now_ms, _wire_size),
    do: error(413, "request-too-large", "Request too large")

  defp respond({:error, _reason}, _frame, _peer_der, _now_ms, _wire_size),
    do: error(400, "invalid-request", "Invalid request")

  defp respond(:more, _frame, _peer_der, _now_ms, wire_size) do
    if wire_size < @maximum_wire_bytes,
      do: :more,
      else: error(413, "request-too-large", "Request too large")
  end

  defp error(status, code, title) do
    body =
      RFC8785.encode!(%{
        "type" => "urn:frameshift:problem:#{code}",
        "title" => title,
        "status" => status
      })

    {:ok, encode(%{status: status, content_type: "application/problem+json", body: body})}
  end

  defp encode(%{status: status, content_type: content_type, body: body}) do
    IO.iodata_to_binary([
      "HTTP/1.1 ",
      Integer.to_string(status),
      " ",
      status_title(status),
      "\r\n",
      "cache-control: no-store\r\n",
      "connection: close\r\n",
      "content-length: ",
      Integer.to_string(byte_size(body)),
      "\r\n",
      "content-type: ",
      content_type,
      "\r\n",
      "x-content-type-options: nosniff\r\n",
      "\r\n",
      body
    ])
  end

  defp status_title(200), do: "OK"
  defp status_title(201), do: "Created"
  defp status_title(400), do: "Bad Request"
  defp status_title(403), do: "Forbidden"
  defp status_title(404), do: "Not Found"
  defp status_title(409), do: "Conflict"
  defp status_title(413), do: "Content Too Large"
  defp status_title(429), do: "Too Many Requests"
  defp status_title(503), do: "Service Unavailable"
end
