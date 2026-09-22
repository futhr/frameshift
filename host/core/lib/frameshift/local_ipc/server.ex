defmodule Frameshift.LocalIPC.Server do
  @moduledoc """
  Bounded Unix-domain socket server for the local macOS shell.

  Each connection carries exactly one four-byte-length-prefixed JSON request
  and response. The containing directory is private to the user and the socket
  is mode `0600`. This boundary does not expose a TCP listener.
  """

  use GenServer

  require Logger

  alias Frameshift.LocalAPI

  @maximum_request_bytes 64 * 1024
  @maximum_response_bytes 1024 * 1024
  @request_timeout_ms 5_000

  defmodule State do
    @moduledoc false
    @enforce_keys [:acceptor, :listener, :path]
    defstruct [:acceptor, :listener, :path]
  end

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
    library = Keyword.get(options, :library, Frameshift.Library)
    task_supervisor = Keyword.get(options, :task_supervisor, Frameshift.TaskSupervisor)

    with :ok <- prepare_path(path),
         {:ok, listener} <- listen(path),
         :ok <- File.chmod(path, 0o600),
         {:ok, acceptor} <- start_acceptor(task_supervisor, listener, library) do
      Process.monitor(acceptor)
      {:ok, %State{acceptor: acceptor, listener: listener, path: path}}
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
    :gen_tcp.close(listener)
    File.rm(path)
    :ok
  end

  defp prepare_path(path) do
    if byte_size(path) > 100 do
      {:error, :socket_path_too_long}
    else
      with :ok <- File.mkdir_p(Path.dirname(path)),
           :ok <- File.chmod(Path.dirname(path), 0o700) do
        remove_stale_socket(path)
      end
    end
  end

  defp remove_stale_socket(path) do
    case File.lstat(path) do
      {:error, :enoent} ->
        :ok

      {:ok, %File.Stat{type: :other}} ->
        case :gen_tcp.connect({:local, path}, 0, socket_options(), 250) do
          {:ok, socket} ->
            :gen_tcp.close(socket)
            {:error, :socket_already_active}

          {:error, :econnrefused} ->
            File.rm(path)

          {:error, :enoent} ->
            :ok

          {:error, _reason} ->
            {:error, :socket_path_busy}
        end

      {:ok, %File.Stat{}} ->
        {:error, :unsafe_socket_path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp listen(path) do
    :gen_tcp.listen(0, [
      :binary,
      {:packet, 4},
      {:packet_size, @maximum_request_bytes},
      {:active, false},
      {:backlog, 16},
      {:ifaddr, {:local, path}}
    ])
  end

  defp start_acceptor(task_supervisor, listener, library) do
    Task.Supervisor.start_child(task_supervisor, fn ->
      accept_loop(task_supervisor, listener, library)
    end)
  end

  defp accept_loop(task_supervisor, listener, library) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        hand_off(task_supervisor, socket, library)
        accept_loop(task_supervisor, listener, library)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        exit({:accept_failed, reason})
    end
  end

  defp hand_off(task_supervisor, socket, library) do
    case Task.Supervisor.start_child(task_supervisor, fn ->
           receive do
             {:serve, ^socket} -> serve(socket, library)
           after
             @request_timeout_ms -> :gen_tcp.close(socket)
           end
         end) do
      {:ok, worker} ->
        case :gen_tcp.controlling_process(socket, worker) do
          :ok -> send(worker, {:serve, socket})
          {:error, _reason} -> :gen_tcp.close(socket)
        end

      {:error, _reason} ->
        :gen_tcp.close(socket)
    end
  end

  defp serve(socket, library) do
    response =
      case :gen_tcp.recv(socket, 0, @request_timeout_ms) do
        {:ok, payload} -> dispatch(payload, library)
        {:error, :timeout} -> error_response(nil, :request_timeout)
        {:error, _reason} -> error_response(nil, :invalid_request)
      end

    with {:ok, encoded} <- RFC8785.encode(response),
         true <- byte_size(encoded) <= @maximum_response_bytes do
      :gen_tcp.send(socket, encoded)
    else
      _failure ->
        :gen_tcp.send(socket, ~s({"ok":false,"version":1,"error":{"code":"internal_error"}}))
    end

    :gen_tcp.close(socket)
  catch
    kind, _reason ->
      Logger.error("local IPC request failed (#{kind})")
      :gen_tcp.close(socket)
  end

  defp dispatch(payload, library) do
    with {:ok, request} <- decode_request(payload),
         {:ok, response} <- execute_request(request, library) do
      response
    else
      {:error, {request_id, code}} -> error_response(request_id, code)
      {:error, code} -> error_response(nil, code)
    end
  end

  defp decode_request(payload) do
    case Wotex.JSON.decode(payload,
           max_bytes: @maximum_request_bytes,
           max_depth: 16,
           max_nodes: 2_048,
           max_string_bytes: 8_192,
           max_collection_size: 256
         ) do
      {:ok, request} when is_map(request) -> validate_request(request)
      {:ok, _not_object} -> {:error, :invalid_request}
      {:error, _reason} -> {:error, :invalid_request}
    end
  end

  defp validate_request(
         %{"version" => 1, "requestId" => request_id, "operation" => operation} = request
       )
       when is_binary(request_id) and byte_size(request_id) in 1..64 and
              operation in ["snapshot", "command"] do
    allowed =
      if operation == "command",
        do: ~w(version requestId operation command),
        else: ~w(version requestId operation)

    cond do
      Enum.any?(Map.keys(request), &(&1 not in allowed)) ->
        {:error, {request_id, :invalid_request}}

      operation == "command" and not is_map(Map.get(request, "command")) ->
        {:error, {request_id, :invalid_command}}

      true ->
        {:ok, request}
    end
  end

  defp validate_request(request) when is_map(request) do
    request_id = Map.get(request, "requestId")
    safe_id = if is_binary(request_id) and byte_size(request_id) in 1..64, do: request_id
    {:error, {safe_id, :invalid_request}}
  end

  defp execute_request(%{"requestId" => request_id, "operation" => "snapshot"}, library) do
    {:ok, success_response(request_id, LocalAPI.snapshot(library))}
  end

  defp execute_request(
         %{"requestId" => request_id, "operation" => "command", "command" => command},
         library
       ) do
    case LocalAPI.execute(library, command) do
      {:ok, snapshot} -> {:ok, success_response(request_id, snapshot)}
      {:error, code} -> {:error, {request_id, code}}
    end
  end

  defp success_response(request_id, snapshot) do
    %{"version" => 1, "requestId" => request_id, "ok" => true, "snapshot" => snapshot}
  end

  defp error_response(request_id, code) do
    %{
      "version" => 1,
      "requestId" => request_id,
      "ok" => false,
      "error" => %{"code" => Atom.to_string(code)}
    }
  end

  defp socket_options do
    [:binary, {:packet, 4}, {:packet_size, @maximum_request_bytes}, {:active, false}]
  end
end
