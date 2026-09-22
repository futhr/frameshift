defmodule Frameshift.LocalIPC.Server do
  @moduledoc """
  Bounded Unix-domain socket server for the local macOS shell.

  Each connection carries exactly one four-byte-length-prefixed JSON request
  and response. The containing directory is private to the user and the socket
  is mode `0600`. This boundary does not expose a TCP listener.
  """

  use GenServer

  require Logger

  alias Frameshift.Digest
  alias Frameshift.Library
  alias Frameshift.LocalAPI

  @maximum_request_bytes 64 * 1024
  @maximum_response_bytes 1024 * 1024
  @request_timeout_ms 5_000
  @token_pattern ~r/^[0-9a-f]{64}$/

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
    token = Keyword.fetch!(options, :token)
    library = Keyword.get(options, :library, Frameshift.Library)
    task_supervisor = Keyword.get(options, :task_supervisor, Frameshift.TaskSupervisor)

    with :ok <- validate_token(token),
         :ok <- prepare_path(path),
         {:ok, listener} <- listen(path),
         :ok <- File.chmod(path, 0o600),
         {:ok, acceptor} <- start_acceptor(task_supervisor, listener, library, token) do
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

  defp start_acceptor(task_supervisor, listener, library, token) do
    Task.Supervisor.start_child(task_supervisor, fn ->
      accept_loop(task_supervisor, listener, library, token)
    end)
  end

  defp accept_loop(task_supervisor, listener, library, token) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        hand_off(task_supervisor, socket, library, token)
        accept_loop(task_supervisor, listener, library, token)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        exit({:accept_failed, reason})
    end
  end

  defp hand_off(task_supervisor, socket, library, token) do
    case Task.Supervisor.start_child(task_supervisor, fn ->
           receive do
             {:serve, ^socket} -> serve(socket, library, token)
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

  defp serve(socket, library, token) do
    response =
      case :gen_tcp.recv(socket, 0, @request_timeout_ms) do
        {:ok, payload} -> dispatch(payload, library, token)
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

  defp dispatch(payload, library, token) do
    with {:ok, request} <- decode_request(payload),
         :ok <- authenticate(request, token),
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
         %{
           "version" => 1,
           "requestId" => request_id,
           "operation" => operation,
           "auth" => auth
         } = request
       ) do
    allowed =
      if operation == "command",
        do: ~w(version requestId operation auth command),
        else: ~w(version requestId operation auth)

    with :ok <- validate_request_id(request_id),
         :ok <- validate_operation(operation),
         :ok <- validate_auth_shape(auth),
         :ok <- validate_request_keys(request, allowed, request_id),
         :ok <- validate_command_shape(request, operation, request_id) do
      {:ok, request}
    end
  end

  defp validate_request(request) when is_map(request) do
    request_id = Map.get(request, "requestId")
    safe_id = if is_binary(request_id) and byte_size(request_id) in 1..64, do: request_id
    {:error, {safe_id, :invalid_request}}
  end

  defp validate_request_id(request_id)
       when is_binary(request_id) and byte_size(request_id) in 1..64,
       do: :ok

  defp validate_request_id(request_id),
    do: {:error, {safe_request_id(request_id), :invalid_request}}

  defp validate_operation(operation) when operation in ["snapshot", "command"], do: :ok
  defp validate_operation(_operation), do: {:error, :invalid_request}

  defp validate_auth_shape(auth) when is_binary(auth) and byte_size(auth) == 64, do: :ok
  defp validate_auth_shape(_auth), do: {:error, :invalid_request}

  defp validate_request_keys(request, allowed, request_id) do
    if Enum.any?(Map.keys(request), &(&1 not in allowed)),
      do: {:error, {request_id, :invalid_request}},
      else: :ok
  end

  defp validate_command_shape(request, "command", request_id) do
    case Map.get(request, "command") do
      %{"id" => command_id} when is_binary(command_id) and byte_size(command_id) in 1..64 ->
        :ok

      _invalid ->
        {:error, {request_id, :invalid_command}}
    end
  end

  defp validate_command_shape(_request, _operation, _request_id), do: :ok

  defp safe_request_id(request_id)
       when is_binary(request_id) and byte_size(request_id) in 1..64,
       do: request_id

  defp safe_request_id(_request_id), do: nil

  defp validate_token(token) when is_binary(token) do
    if Regex.match?(@token_pattern, token), do: :ok, else: {:error, :invalid_ipc_token}
  end

  defp validate_token(_token), do: {:error, :invalid_ipc_token}

  defp authenticate(%{"requestId" => request_id, "auth" => candidate}, token) do
    if secure_equal?(candidate, token),
      do: :ok,
      else: {:error, {request_id, :authentication_required}}
  end

  defp secure_equal?(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {left_byte, right_byte}, difference ->
      Bitwise.bor(difference, Bitwise.bxor(left_byte, right_byte))
    end)
    |> Kernel.==(0)
  end

  defp secure_equal?(_left, _right), do: false

  defp execute_request(%{"requestId" => request_id, "operation" => "snapshot"}, library) do
    {:ok, success_response(request_id, LocalAPI.snapshot(library))}
  end

  defp execute_request(
         %{"requestId" => request_id, "operation" => "command", "command" => command},
         library
       ) do
    with {:ok, command_hash} <- command_hash(command),
         {:ok, disposition} <- Library.claim_command(library, command["id"], command_hash) do
      execute_command(disposition, request_id, command, command_hash, library)
    else
      {:error, code} -> {:error, {request_id, code}}
    end
  end

  defp execute_command(:execute, request_id, command, command_hash, library) do
    outcome = LocalAPI.execute(library, command)

    receipt_outcome =
      case outcome do
        {:ok, _snapshot} -> :ok
        {:error, code} -> {:error, code}
      end

    case Library.complete_command(library, command["id"], command_hash, receipt_outcome) do
      :ok -> command_response(request_id, outcome)
      {:error, _reason} -> {:error, {request_id, :command_outcome_unknown}}
    end
  end

  defp execute_command({:replay, :ok}, request_id, _command, _command_hash, library) do
    {:ok, success_response(request_id, LocalAPI.snapshot(library, "Command already applied"))}
  end

  defp execute_command(
         {:replay, {:error, error_code}},
         request_id,
         _command,
         _command_hash,
         _library
       ) do
    {:error, {request_id, error_code}}
  end

  defp execute_command(:pending, request_id, _command, _command_hash, _library),
    do: {:error, {request_id, :command_outcome_unknown}}

  defp command_response(request_id, {:ok, snapshot}),
    do: {:ok, success_response(request_id, snapshot)}

  defp command_response(request_id, {:error, code}), do: {:error, {request_id, code}}

  defp command_hash(command) do
    canonical_result =
      command
      |> Map.delete("importCanonicalPath")
      |> RFC8785.encode()

    case canonical_result do
      {:ok, canonical} -> {:ok, Digest.sha256(canonical)}
      {:error, _reason} -> {:error, :invalid_command}
    end
  end

  defp success_response(request_id, snapshot) do
    %{"version" => 1, "requestId" => request_id, "ok" => true, "snapshot" => snapshot}
  end

  defp error_response(request_id, code) do
    encoded_code = if is_atom(code), do: Atom.to_string(code), else: code

    %{
      "version" => 1,
      "requestId" => request_id,
      "ok" => false,
      "error" => %{"code" => encoded_code}
    }
  end

  defp socket_options do
    [:binary, {:packet, 4}, {:packet_size, @maximum_request_bytes}, {:active, false}]
  end
end
