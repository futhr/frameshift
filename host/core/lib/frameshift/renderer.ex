defmodule Frameshift.Renderer do
  @moduledoc """
  Owns and bounds the isolated `frameshift-raster` executable.

  The worker handles one render at a time. A timeout, worker exit, or malformed
  response terminates this owner so its supervisor starts a clean process.
  """

  use GenServer

  alias Frameshift.Renderer.Protocol

  @default_timeout_ms 30_000
  @maximum_response_bytes Protocol.maximum_frame_bytes()

  defmodule State do
    @moduledoc false
    @enforce_keys [:port]
    defstruct [:port, :pending, :expected, prefix: <<>>, chunks: [], received: 0]
  end

  @type server :: GenServer.server()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec render(server(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def render(server \\ __MODULE__, job, options \\ []) do
    timeout = Keyword.get(options, :deadline_ms, @default_timeout_ms)
    GenServer.call(server, {:render, job, timeout}, call_timeout(timeout))
  end

  @impl true
  def init(options) do
    Process.flag(:trap_exit, true)
    path = options |> Keyword.fetch!(:path) |> Path.expand()

    with :ok <- validate_options(path),
         {:ok, port} <- open_worker(path) do
      {:ok, %State{port: port}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call({:render, _job, _timeout}, _from, %{pending: pending} = state)
      when pending != nil do
    {:reply, {:error, :busy}, state}
  end

  def handle_call({:render, job, timeout}, from, state) do
    with :ok <- validate_timeout(timeout),
         {:ok, request} <- Protocol.encode_request(job),
         :ok <- command_worker(state.port, request) do
      reference = make_ref()
      timer = Process.send_after(self(), {:render_timeout, reference}, timeout)
      pending = %{from: from, timer: timer, reference: reference}
      {:noreply, %{state | pending: pending}}
    else
      {:error, :worker_unavailable} ->
        {:stop, :worker_unavailable, {:error, :worker_unavailable}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    receive_data(state, data)
  end

  def handle_info({:render_timeout, reference}, %{pending: %{reference: reference}} = state) do
    GenServer.reply(state.pending.from, {:error, :timeout})
    {:stop, :render_timeout, clear_pending(state)}
  end

  def handle_info({:render_timeout, _stale_reference}, state), do: {:noreply, state}

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    reply_pending(state, {:error, {:worker_exit, status}})
    {:stop, {:worker_exit, status}, %{clear_pending(state) | port: nil}}
  end

  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    reply_pending(state, {:error, {:worker_exit, reason}})
    {:stop, {:worker_exit, reason}, %{clear_pending(state) | port: nil}}
  end

  @impl true
  def format_status(status) do
    status
    |> Map.update(:state, nil, fn
      %State{} = state -> %{state | prefix: "<redacted>", chunks: [:redacted]}
      _state -> :redacted
    end)
    |> Map.put(:message, :redacted)
    |> Map.put(:log, [:redacted])
  end

  @impl true
  def terminate(_reason, %{port: port}) when is_port(port) do
    if Port.info(port), do: Port.close(port)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp receive_data(%{pending: nil} = state, _data),
    do: fail_worker(state, :unexpected_response)

  defp receive_data(%{expected: nil} = state, data) do
    combined = state.prefix <> data

    if byte_size(combined) < 4 do
      {:noreply, %{state | prefix: combined}}
    else
      <<expected::unsigned-big-32, first_chunk::binary>> = combined
      begin_response(state, expected, first_chunk)
    end
  end

  defp receive_data(state, data) do
    continue_response(state, data)
  end

  defp begin_response(state, expected, _first_chunk)
       when expected > @maximum_response_bytes,
       do: fail_worker(state, :response_too_large)

  defp begin_response(state, expected, first_chunk) do
    next_state = %{state | expected: expected, prefix: <<>>, chunks: [], received: 0}
    continue_response(next_state, first_chunk)
  end

  defp continue_response(state, chunk) do
    received = state.received + byte_size(chunk)

    cond do
      received > state.expected ->
        fail_worker(state, :multiple_responses)

      received < state.expected ->
        {:noreply, %{state | chunks: [chunk | state.chunks], received: received}}

      true ->
        body = state.chunks |> Enum.reverse([chunk]) |> IO.iodata_to_binary()
        finish_response(state, body)
    end
  end

  defp finish_response(state, body) do
    case Protocol.decode_response(body) do
      {:ok, result} -> reply_result(state, result)
      {:error, reason} -> fail_worker(state, reason)
    end
  end

  defp reply_result(state, {:ok, rendered}) do
    GenServer.reply(state.pending.from, {:ok, rendered})
    {:noreply, clear_pending(state)}
  end

  defp reply_result(state, {:worker_error, reason}) do
    GenServer.reply(state.pending.from, {:error, reason})
    {:noreply, clear_pending(state)}
  end

  defp fail_worker(state, reason) do
    reply_pending(state, {:error, {:invalid_worker_response, reason}})
    {:stop, {:invalid_worker_response, reason}, clear_pending(state)}
  end

  defp clear_pending(%{pending: nil} = state), do: reset_response(state)

  defp clear_pending(state) do
    Process.cancel_timer(state.pending.timer)
    state |> Map.put(:pending, nil) |> reset_response()
  end

  defp reset_response(state) do
    %{state | prefix: <<>>, chunks: [], received: 0, expected: nil}
  end

  defp reply_pending(%{pending: nil}, _reply), do: :ok
  defp reply_pending(state, reply), do: GenServer.reply(state.pending.from, reply)

  defp validate_options(path) do
    if File.regular?(path), do: :ok, else: {:error, :renderer_not_found}
  end

  defp validate_timeout(timeout) when is_integer(timeout) and timeout > 0, do: :ok
  defp validate_timeout(_timeout), do: {:error, :invalid_timeout}

  defp call_timeout(timeout) when is_integer(timeout) and timeout > 0, do: timeout + 1_000
  defp call_timeout(_timeout), do: @default_timeout_ms + 1_000

  defp command_worker(port, request) do
    Port.command(port, request)
    :ok
  rescue
    ArgumentError -> {:error, :worker_unavailable}
  end

  defp open_worker(path) do
    port =
      Port.open(
        {:spawn_executable, String.to_charlist(path)},
        [:binary, :exit_status, :stream, :use_stdio]
      )

    {:ok, port}
  rescue
    ArgumentError -> {:error, :renderer_start_failed}
  end
end
