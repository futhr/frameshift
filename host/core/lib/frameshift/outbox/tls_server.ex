defmodule Frameshift.Outbox.TLSServer do
  @moduledoc """
  Runs the reference host outbox on a bounded mutual-TLS socket.

  The listener requires an explicit host certificate and OTP-compatible key
  handle or signer, an
  explicit bind address, and a supervised worker pool. During the TLS
  handshake it accepts only a certificate whose SPKI resolves to exactly one
  paired pull-capable frame. The DER certificate returned by the established
  TLS socket is the only identity passed to the HTTP exchange; request fields
  cannot impersonate another frame.

  This module does not obtain or persist the host identity. The macOS
  credential broker must supply an OTP-compatible identity when background
  outbox service is enabled; a non-exportable Keychain key needs a compatible
  signing bridge rather than extraction into a file.
  """

  use GenServer

  alias Frameshift.Library
  alias Frameshift.Outbox.HTTP1
  alias Frameshift.Transport.SPKIPin

  @handshake_timeout_ms 5_000
  @request_timeout_ms 5_000
  @accepted_chain_errors [:unknown_ca, :selfsigned_peer]

  defmodule State do
    @moduledoc """
    Owns the TLS listen socket and its supervised accept loop.

    Every accepted connection is handed to a separate bounded task, so a slow
    handshake cannot stop other frames from contacting the host.
    """

    @enforce_keys [:acceptor, :listener]
    defstruct [:acceptor, :listener]

    @type t :: %__MODULE__{acceptor: pid(), listener: term()}
  end

  @doc "Starts a listener with explicit TLS identity and a bounded task supervisor."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @doc "Returns the bound port, including an OS-selected port used by tests."
  @spec port(GenServer.server()) :: {:ok, :inet.port_number()} | {:error, term()}
  def port(server \\ __MODULE__), do: GenServer.call(server, :port)

  @impl true
  def init(options) do
    library = Keyword.get(options, :library, Library)
    task_supervisor = Keyword.fetch!(options, :task_supervisor)
    bind_address = Keyword.fetch!(options, :bind_address)
    port = Keyword.fetch!(options, :port)
    certificate = Keyword.fetch!(options, :certificate)
    private_key = Keyword.fetch!(options, :private_key)

    with :ok <- validate_options(bind_address, port, certificate, private_key),
         {:ok, listener} <- listen(bind_address, port, certificate, private_key, library) do
      finish_start(task_supervisor, listener, library)
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  defp finish_start(task_supervisor, listener, library) do
    case start_acceptor(task_supervisor, listener, library) do
      {:ok, acceptor} ->
        Process.monitor(acceptor)
        {:ok, %State{acceptor: acceptor, listener: listener}}

      {:error, reason} ->
        :ssl.close(listener)
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:port, _from, %State{listener: listener} = state) do
    result =
      case :ssl.sockname(listener) do
        {:ok, {_address, port}} -> {:ok, port}
        {:error, reason} -> {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info(
        {:DOWN, _reference, :process, acceptor, reason},
        %State{acceptor: acceptor} = state
      ) do
    {:stop, {:acceptor_stopped, reason}, state}
  end

  @impl true
  def terminate(_reason, %State{listener: listener}) do
    :ssl.close(listener)
    :ok
  end

  @doc "Pins a presented client certificate during the OTP TLS verification callback."
  @spec verify_client(tuple(), term(), map()) ::
          {:valid, map()} | {:unknown, map()} | {:fail, term()}
  def verify_client(_certificate, {:bad_cert, reason}, state)
      when reason in @accepted_chain_errors,
      do: {:valid, state}

  def verify_client(_certificate, {:bad_cert, reason}, _state),
    do: {:fail, {:bad_cert, reason}}

  def verify_client(_certificate, {:extension, _extension}, state), do: {:unknown, state}
  def verify_client(_certificate, :valid, state), do: {:valid, state}

  def verify_client(certificate, :valid_peer, %{library: library} = state) do
    with {:ok, digest} <- SPKIPin.fingerprint(certificate),
         fingerprint = "sha256:" <> Base.encode16(digest, case: :lower),
         {:ok, %{"capabilities" => %{"transferModes" => modes}}} <-
           Library.get_paired_frame_by_spki(library, fingerprint),
         true <- "pull" in modes do
      {:valid, Map.put(state, :matched, true)}
    else
      _failure -> {:fail, :unpaired_frame}
    end
  end

  def verify_client(_certificate, _event, state), do: {:unknown, state}

  defp validate_options(bind_address, port, certificate, private_key) do
    if valid_address?(bind_address) and is_integer(port) and port in 0..65_535 and
         is_binary(certificate) and byte_size(certificate) in 1..65_536 and
         (match?({_type, _value}, private_key) or is_map(private_key)) do
      :ok
    else
      {:error, :invalid_listener_options}
    end
  end

  defp valid_address?(address) when is_tuple(address) and tuple_size(address) == 4 do
    address |> Tuple.to_list() |> Enum.all?(&(&1 in 0..255))
  end

  defp valid_address?(address) when is_tuple(address) and tuple_size(address) == 8 do
    address |> Tuple.to_list() |> Enum.all?(&(&1 in 0..65_535))
  end

  defp valid_address?(_address), do: false

  defp listen(bind_address, port, certificate, private_key, library) do
    :ssl.listen(port,
      ip: bind_address,
      active: false,
      mode: :binary,
      reuseaddr: true,
      backlog: 16,
      cert: certificate,
      key: private_key,
      verify: :verify_peer,
      fail_if_no_peer_cert: true,
      certificate_authorities: false,
      cacerts: [],
      verify_fun: {&verify_client/3, %{library: library}},
      versions: [:"tlsv1.3"],
      max_handshake_size: 65_536,
      session_tickets: :disabled,
      alpn_preferred_protocols: ["http/1.1"]
    )
  end

  defp start_acceptor(task_supervisor, listener, library) do
    Task.Supervisor.start_child(task_supervisor, fn ->
      accept_loop(task_supervisor, listener, library)
    end)
  end

  defp accept_loop(task_supervisor, listener, library) do
    case :ssl.transport_accept(listener) do
      {:ok, socket} ->
        hand_off(task_supervisor, socket, library)
        accept_loop(task_supervisor, listener, library)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        exit({:outbox_accept_failed, reason})
    end
  end

  defp hand_off(task_supervisor, socket, library) do
    case Task.Supervisor.start_child(task_supervisor, fn ->
           receive do
             {:serve, ^socket} -> serve(socket, library)
           after
             @handshake_timeout_ms -> :ssl.close(socket)
           end
         end) do
      {:ok, worker} ->
        case :ssl.controlling_process(socket, worker) do
          :ok -> send(worker, {:serve, socket})
          {:error, _reason} -> :ssl.close(socket)
        end

      {:error, _reason} ->
        :ssl.close(socket)
    end
  end

  defp serve(socket, library) do
    case :ssl.handshake(socket, @handshake_timeout_ms) do
      {:ok, established} ->
        serve_authenticated(established, library)
        :ssl.close(established)

      {:error, _reason} ->
        :ssl.close(socket)
    end
  end

  defp serve_authenticated(socket, library) do
    with {:ok, certificate} <- :ssl.peercert(socket),
         deadline = System.monotonic_time(:millisecond) + @request_timeout_ms do
      read_exchange(socket, library, certificate, <<>>, deadline)
    end
  end

  defp read_exchange(socket, library, certificate, wire, deadline) do
    case HTTP1.exchange(library, certificate, wire) do
      {:ok, response} ->
        :ssl.send(socket, response)

      :more ->
        remaining = deadline - System.monotonic_time(:millisecond)

        if remaining > 0 and byte_size(wire) < HTTP1.maximum_wire_bytes() do
          receive_more(socket, library, certificate, wire, deadline, remaining)
        else
          :ok
        end
    end
  end

  defp receive_more(socket, library, certificate, wire, deadline, remaining) do
    case :ssl.recv(socket, 0, remaining) do
      {:ok, bytes} -> read_exchange(socket, library, certificate, wire <> bytes, deadline)
      {:error, _reason} -> :ok
    end
  end
end
