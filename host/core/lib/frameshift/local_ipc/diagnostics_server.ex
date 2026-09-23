defmodule Frameshift.LocalIPC.DiagnosticsServer do
  @moduledoc """
  Peer-authenticated, read-only diagnostics over a private Unix socket.

  This endpoint has no mutation dispatch and accepts no shell bootstrap token.
  Each connection handles one bounded length-framed JSON request.
  """

  use GenServer

  alias Frameshift.Diagnostics.Metrics
  alias Frameshift.Library
  alias Frameshift.LocalIPC.PeerIdentity

  @maximum_request_bytes 8_192
  @maximum_response_bytes 256 * 1024
  @request_timeout_ms 5_000

  defmodule State do
    @moduledoc "Owns the listener and its supervised acceptor."

    @type t :: %__MODULE__{listener: :socket.socket(), path: String.t(), acceptor: pid()}

    @enforce_keys [:listener, :path, :acceptor]
    defstruct [:listener, :path, :acceptor]
  end

  @doc "Starts a read-only local socket in a private user directory."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @impl true
  def init(options) do
    path = options |> Keyword.fetch!(:path) |> Path.expand()
    library = Keyword.get(options, :library, Library)
    metrics = Keyword.get(options, :metrics, Metrics)
    task_supervisor = Keyword.get(options, :task_supervisor, Frameshift.TaskSupervisor)

    with :ok <- prepare_path(path),
         {:ok, listener} <- :socket.open(:local, :stream, :default),
         :ok <- :socket.bind(listener, %{family: :local, path: path}),
         :ok <- :socket.listen(listener, 16),
         :ok <- File.chmod(path, 0o600),
         {:ok, directory} <- File.lstat(Path.dirname(path)),
         {:ok, acceptor} <-
           Task.Supervisor.start_child(task_supervisor, fn ->
             accept_loop(listener, directory.uid, library, metrics)
           end) do
      Process.monitor(acceptor)
      {:ok, %State{listener: listener, path: path, acceptor: acceptor}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_info(
        {:DOWN, _reference, :process, acceptor, reason},
        %State{acceptor: acceptor} = state
      ) do
    {:stop, {:acceptor_stopped, reason}, state}
  end

  @impl true
  def terminate(_reason, %State{listener: listener, path: path}) do
    :socket.close(listener)
    File.rm(path)
    :ok
  end

  defp prepare_path(path) do
    if byte_size(path) > 100 do
      {:error, :socket_path_too_long}
    else
      parent = Path.dirname(path)

      with :ok <- File.mkdir_p(parent),
           :ok <- File.chmod(parent, 0o700),
           {:ok, %File.Stat{type: :directory, mode: mode}} <- File.lstat(parent),
           true <- Bitwise.band(mode, 0o077) == 0 do
        remove_stale_socket(path)
      else
        _unsafe -> {:error, :unsafe_diagnostics_directory}
      end
    end
  end

  defp remove_stale_socket(path) do
    case File.lstat(path) do
      {:error, :enoent} ->
        :ok

      {:ok, %File.Stat{type: :other}} ->
        with {:ok, socket} <- :socket.open(:local, :stream, :default) do
          check_stale_socket(socket, path)
        end

      _other ->
        {:error, :unsafe_socket_path}
    end
  end

  defp check_stale_socket(socket, path) do
    result = :socket.connect(socket, %{family: :local, path: path})
    :socket.close(socket)

    case result do
      :ok -> {:error, :socket_already_active}
      {:error, :econnrefused} -> File.rm(path)
      _other -> {:error, :socket_path_busy}
    end
  end

  defp accept_loop(listener, owner_uid, library, metrics) do
    case :socket.accept(listener) do
      {:ok, socket} ->
        serve(socket, owner_uid, library, metrics)
        accept_loop(listener, owner_uid, library, metrics)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        exit({:diagnostics_accept_failed, reason})
    end
  end

  defp serve(socket, owner_uid, library, metrics) do
    response =
      with {:ok, ^owner_uid} <- PeerIdentity.uid(socket),
           {:ok, payload} <- read_request(socket),
           {:ok, request} <- decode_request(payload) do
        dispatch(request, library, metrics)
      else
        {:ok, _different_uid} -> error_response(nil, :authentication_required)
        {:error, _reason} -> error_response(nil, :invalid_request)
      end

    encoded = RFC8785.encode!(response)

    if byte_size(encoded) <= @maximum_response_bytes do
      :socket.send(socket, <<byte_size(encoded)::unsigned-big-32, encoded::binary>>)
    end

    :socket.close(socket)
  catch
    _kind, _reason ->
      :socket.close(socket)
  end

  defp read_request(socket) do
    deadline = System.monotonic_time(:millisecond) + @request_timeout_ms

    with {:ok, <<length::unsigned-big-32>>} <- read_exact(socket, 4, deadline, []),
         true <- length in 1..@maximum_request_bytes,
         {:ok, payload} <- read_exact(socket, length, deadline, []) do
      {:ok, payload}
    else
      _invalid -> {:error, :invalid_request}
    end
  end

  defp read_exact(_socket, 0, _deadline, parts),
    do: {:ok, parts |> Enum.reverse() |> IO.iodata_to_binary()}

  defp read_exact(socket, count, deadline, parts) do
    remaining_ms = deadline - System.monotonic_time(:millisecond)

    if remaining_ms <= 0 do
      {:error, :timeout}
    else
      case :socket.recv(socket, count, remaining_ms) do
        {:ok, bytes} when byte_size(bytes) > 0 ->
          read_exact(socket, count - byte_size(bytes), deadline, [bytes | parts])

        {:error, reason} ->
          {:error, reason}

        _empty ->
          {:error, :closed}
      end
    end
  end

  defp decode_request(payload) do
    with {:ok, request} <-
           Wotex.JSON.decode(payload,
             max_bytes: @maximum_request_bytes,
             max_depth: 8,
             max_nodes: 128,
             max_string_bytes: 256,
             max_collection_size: 16
           ),
         %{"version" => 1, "requestId" => request_id, "operation" => operation} <- request,
         true <- is_binary(request_id) and byte_size(request_id) in 1..64,
         true <- operation in ~w(health metrics audit),
         true <-
           Enum.all?(Map.keys(request), &(&1 in ~w(version requestId operation cursor limit))),
         true <- valid_page(request) do
      {:ok, request}
    else
      _invalid -> {:error, :invalid_request}
    end
  end

  defp valid_page(%{"operation" => "health"} = request) do
    Map.keys(request) -- ~w(version requestId operation) == []
  end

  defp valid_page(request) do
    cursor = Map.get(request, "cursor")
    limit = Map.get(request, "limit", 50)

    (is_nil(cursor) or (is_integer(cursor) and cursor >= 0)) and
      is_integer(limit) and limit in 1..100
  end

  defp dispatch(%{"requestId" => request_id, "operation" => "health"}, library, metrics) do
    collector =
      try do
        Map.put(Metrics.status(metrics), "available", true)
      catch
        :exit, _reason -> %{"available" => false}
      end

    success_response(request_id, %{
      "store" => Library.diagnostics_health(library),
      "collector" => collector,
      "observedAtMs" => System.os_time(:millisecond)
    })
  end

  defp dispatch(
         %{"requestId" => request_id, "operation" => operation} = request,
         library,
         metrics
       ) do
    cursor = Map.get(request, "cursor")
    limit = Map.get(request, "limit", 50)

    result =
      case operation do
        "metrics" -> Library.metric_page(library, cursor, limit)
        "audit" -> Library.audit_page(library, cursor, limit)
      end

    case result do
      {:error, code} ->
        error_response(request_id, code)

      page ->
        diagnostics =
          if operation == "metrics",
            do: Map.put(page, "coverage", Metrics.status(metrics)),
            else: page

        success_response(request_id, diagnostics)
    end
  end

  defp success_response(request_id, data) do
    %{"version" => 1, "requestId" => request_id, "ok" => true, "diagnostics" => data}
  end

  defp error_response(request_id, code) do
    %{
      "version" => 1,
      "requestId" => request_id,
      "ok" => false,
      "error" => %{"code" => Atom.to_string(code)}
    }
  end
end
