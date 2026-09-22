defmodule Frameshift.Transport.HTTPClient do
  @moduledoc """
  One-shot reference HTTPS client for the Wotex HTTP binding.

  The adapter owns every network policy the binding intentionally leaves to
  its consumer: exact credential audience, DNS/IP admission, mutual TLS,
  pinned frame identity, absolute deadlines, response limits, and redirect
  refusal. Connections are never pooled, so client credentials exist only for
  the duration of the immediate callback.

  This client currently implements finite Property and Action exchanges. SSE
  subscription lifecycle is rejected explicitly until a separately supervised,
  bounded stream owner is installed.
  """

  @behaviour Wotex.Binding.HTTP.Client

  alias Frameshift.Transport.{MTLSCredential, SPKIPin, SystemResolver}
  alias Wotex.Binding.HTTP.{Headers, Request, Response}
  alias Wotex.Runtime.Context

  @default_config %{
    resolver: {SystemResolver, nil},
    allow_loopback: false,
    tls_versions: [:"tlsv1.3", :"tlsv1.2"]
  }
  @status_line_allowance 512
  @header_wire_allowance 4

  @impl Wotex.Binding.HTTP.Client
  def request(%Request{} = request, %MTLSCredential{} = credential, config)
      when is_map(config) do
    config = Map.merge(@default_config, config)

    with {:ok, uri} <- authorize_target(Request.uri(request), credential),
         {:ok, timeout} <- remaining_timeout(Request.deadline(request)),
         {:ok, addresses} <- resolve_addresses(uri.host, config),
         :ok <- authorize_addresses(addresses, config),
         {:ok, connection} <- connect(addresses, uri, credential, request, timeout, config) do
      execute(connection, uri, request)
    else
      {:error, reason} when is_atom(reason) -> {:error, reason}
    end
  rescue
    _exception -> {:error, :transport_failure}
  catch
    _kind, _reason -> {:error, :transport_failure}
  end

  def request(_request, _credential, _config), do: {:error, :invalid_client_arguments}

  @impl Wotex.Binding.HTTP.Client
  def subscribe(_request, _credential, _owner, _config),
    do: {:error, :streaming_not_available}

  @impl Wotex.Binding.HTTP.Client
  def close(_handle, _config), do: {:error, :unknown_subscription}

  defp authorize_target(target, credential) do
    with {:ok, uri} <- URI.new(target),
         true <- uri.scheme == "https",
         true <- is_binary(uri.host) and uri.host != "",
         true <- is_nil(uri.userinfo) and is_nil(uri.fragment),
         port when port in 1..65_535 <- uri.port || 443,
         true <- String.downcase(uri.host) == credential.host and port == credential.port do
      {:ok, %{uri | port: port}}
    else
      _other -> {:error, :credential_audience_mismatch}
    end
  end

  defp remaining_timeout(deadline) when is_integer(deadline) do
    normalize_timeout(Context.remaining_ms(deadline, System.monotonic_time(:millisecond)))
  end

  defp remaining_timeout(%DateTime{} = deadline) do
    normalize_timeout(Context.remaining_ms(deadline, DateTime.utc_now()))
  end

  defp remaining_timeout(_deadline), do: {:error, :deadline_required}

  defp normalize_timeout(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp normalize_timeout(_value), do: {:error, :timeout}

  defp resolve_addresses(host, %{resolver: {module, resolver_config}}) when is_atom(module) do
    case module.resolve(host, resolver_config) do
      {:ok, [_ | _] = addresses} -> {:ok, Enum.uniq(addresses)}
      {:error, reason} when is_atom(reason) -> {:error, reason}
      _other -> {:error, :resolver_contract_violation}
    end
  end

  defp resolve_addresses(_host, _config), do: {:error, :invalid_resolver}

  defp authorize_addresses(addresses, config) do
    if Enum.all?(addresses, &local_address?(&1, config.allow_loopback)),
      do: :ok,
      else: {:error, :destination_forbidden}
  end

  defp local_address?({10, _, _, _}, _allow_loopback), do: true
  defp local_address?({172, second, _, _}, _allow_loopback) when second in 16..31, do: true
  defp local_address?({192, 168, _, _}, _allow_loopback), do: true
  defp local_address?({169, 254, _, _}, _allow_loopback), do: true
  defp local_address?({127, _, _, _}, true), do: true
  defp local_address?({0, 0, 0, 0, 0, 0, 0, 1}, true), do: true

  defp local_address?({first, _, _, _, _, _, _, _}, _allow_loopback)
       when Bitwise.band(first, 0xFE00) == 0xFC00,
       do: true

  defp local_address?({0xFE80, _, _, _, _, _, _, _}, _allow_loopback), do: true

  defp local_address?({0, 0, 0, 0, 0, 0xFFFF, high, low}, allow_loopback) do
    local_address?(
      {Bitwise.bsr(high, 8), Bitwise.band(high, 0xFF), Bitwise.bsr(low, 8),
       Bitwise.band(low, 0xFF)},
      allow_loopback
    )
  end

  defp local_address?(_address, _allow_loopback), do: false

  defp connect(addresses, uri, credential, request, timeout, config) do
    options = [
      hostname: uri.host,
      protocols: [:http1],
      mode: :passive,
      max_header_list_size: header_wire_limit(request),
      transport_opts: [
        verify: :verify_peer,
        cacerts: [],
        cert: credential.client_certificate,
        key: credential.client_private_key,
        versions: config.tls_versions,
        timeout: timeout,
        verify_fun: {&SPKIPin.verify/3, %{expected: credential.server_spki_sha256}}
      ]
    ]

    connect_next(addresses, uri.port, options, Request.deadline(request))
  end

  defp connect_next([], _port, _options, _deadline), do: {:error, :connection_failed}

  defp connect_next([address | rest], port, options, deadline) do
    with {:ok, timeout} <- remaining_timeout(deadline) do
      updated_options =
        update_in(options, [:transport_opts], &Keyword.put(&1, :timeout, timeout))

      case Mint.HTTP.connect(:https, address, port, updated_options) do
        {:ok, connection} -> {:ok, connection}
        {:error, _reason} -> connect_next(rest, port, options, deadline)
      end
    end
  end

  defp execute(connection, uri, request) do
    path = request_path(uri)
    body = Request.body(request)

    case Mint.HTTP.request(
           connection,
           Request.method(request),
           path,
           Request.headers(request),
           body
         ) do
      {:ok, connection, reference} ->
        receive_response(connection, reference, request, empty_response())

      {:error, _connection, _reason} ->
        {:error, :request_failed}
    end
  after
    Mint.HTTP.close(connection)
  end

  defp receive_response(connection, reference, request, response) do
    with {:ok, timeout} <- remaining_timeout(Request.deadline(request)) do
      case Mint.HTTP.recv(connection, 0, timeout) do
        {:ok, next_connection, parts} ->
          handle_parts(parts, next_connection, reference, request, response)

        {:error, _connection, %Mint.TransportError{reason: :timeout}, _parts} ->
          {:error, :timeout}

        {:error, _connection, _reason, _parts} ->
          {:error, :response_failed}
      end
    end
  end

  defp handle_parts(parts, connection, reference, request, response) do
    case consume_parts(parts, reference, request, response) do
      {:continue, next_response} ->
        receive_response(connection, reference, request, next_response)

      {:done, complete} ->
        build_response(complete, request)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp empty_response,
    do: %{status: nil, headers: nil, body: [], body_bytes: 0, done?: false}

  defp consume_parts(parts, reference, request, response) do
    Enum.reduce_while(parts, {:continue, response}, fn part, {:continue, accumulator} ->
      case consume_part(part, reference, request, accumulator) do
        {:continue, next} -> {:cont, {:continue, next}}
        {:done, next} -> {:halt, {:done, next}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp consume_part({:status, reference, status}, reference, _request, %{status: nil} = response)
       when status in 100..599,
       do: {:continue, %{response | status: status}}

  defp consume_part({:headers, reference, headers}, reference, request, response)
       when is_list(headers) and is_nil(response.headers) do
    with :ok <- validate_headers(headers, request),
         :ok <- validate_content_length(headers, Request.max_response_bytes(request)) do
      {:continue, %{response | headers: headers}}
    end
  end

  defp consume_part({:data, reference, data}, reference, request, response)
       when is_binary(data) do
    body_bytes = response.body_bytes + byte_size(data)

    if body_bytes <= Request.max_response_bytes(request) do
      {:continue, %{response | body: [data | response.body], body_bytes: body_bytes}}
    else
      {:error, :response_too_large}
    end
  end

  defp consume_part({:done, reference}, reference, _request, response) do
    if is_integer(response.status) and is_list(response.headers),
      do: {:done, %{response | done?: true}},
      else: {:error, :incomplete_response}
  end

  defp consume_part({:error, reference, _reason}, reference, _request, _response),
    do: {:error, :response_failed}

  defp consume_part({_kind, other_reference, _value}, reference, _request, response)
       when other_reference != reference,
       do: {:continue, response}

  defp consume_part(_part, _reference, _request, _response),
    do: {:error, :response_contract_violation}

  defp validate_headers(headers, request) do
    with {:ok, normalized} <- Headers.new(headers, :response),
         :ok <-
           Headers.validate_limits(
             normalized,
             Request.max_header_count(request),
             Request.max_header_bytes(request),
             :response
           ) do
      :ok
    else
      {:error, _error} -> {:error, :invalid_response_headers}
    end
  end

  defp validate_content_length(headers, maximum) do
    values =
      for {name, value} <- headers,
          String.downcase(name) == "content-length",
          do: value

    case values do
      [] ->
        :ok

      [value] ->
        case Integer.parse(value) do
          {length, ""} when length >= 0 and length <= maximum -> :ok
          {length, ""} when length > maximum -> {:error, :response_too_large}
          _other -> {:error, :invalid_content_length}
        end

      _multiple ->
        {:error, :invalid_content_length}
    end
  end

  defp build_response(%{status: status, headers: headers, body: body, done?: true}, _request) do
    case Response.new(status, headers, body |> Enum.reverse() |> IO.iodata_to_binary()) do
      {:ok, response} -> {:ok, response}
      {:error, _error} -> {:error, :invalid_response}
    end
  end

  defp request_path(%URI{path: path, query: query}) do
    base = if path in [nil, ""], do: "/", else: path
    if is_binary(query), do: "#{base}?#{query}", else: base
  end

  defp header_wire_limit(request) do
    Request.max_header_bytes(request) +
      Request.max_header_count(request) * @header_wire_allowance + @status_line_allowance
  end
end
