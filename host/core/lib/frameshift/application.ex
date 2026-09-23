defmodule Frameshift.Application do
  @moduledoc """
  Starts the durable core and its supervised local boundaries.

  Library, renderer, and local IPC children are selected by release
  configuration. The IPC bootstrap challenge is consumed before the listener
  starts, so no unauthenticated command window is opened during boot.
  """

  use Application

  alias Frameshift.Diagnostics.LogFormatter
  alias Frameshift.Diagnostics.Metrics
  alias Frameshift.LocalIPC.DiagnosticsServer
  alias Frameshift.LocalIPC.Token
  alias Frameshift.Transport.KeychainBroker

  @impl true
  def start(_type, _args) do
    children =
      [
        {Task.Supervisor, name: Frameshift.TaskSupervisor}
      ] ++ library_children() ++ metrics_children() ++ renderer_children() ++ local_ipc_children()

    case Supervisor.start_link(children, strategy: :one_for_one, name: Frameshift.Supervisor) do
      {:ok, _supervisor} = started ->
        configure_fallback_logging()
        started

      error ->
        error
    end
  end

  defp configure_fallback_logging do
    if Application.get_env(:frameshift_core, :start_local_ipc, false) do
      directory = Path.join(Frameshift.Paths.data_dir(), "diagnostics")
      :ok = File.mkdir_p(directory)
      :ok = File.chmod(directory, 0o700)
      path = Path.join(directory, "core-fallback.log")

      config = %{
        level: :error,
        formatter: {LogFormatter, %{}},
        config: %{
          type: :file,
          file: String.to_charlist(path),
          max_no_bytes: 2 * 1024 * 1024,
          max_no_files: 3
        }
      }

      case :logger.add_handler(:frameshift_fallback, :logger_std_h, config) do
        :ok -> File.chmod(path, 0o600)
        {:error, {:already_exist, _handler}} -> :ok
        {:error, reason} -> raise "could not start fallback logging: #{inspect(reason)}"
      end
    end
  end

  defp library_children do
    if Application.fetch_env!(:frameshift_core, :start_library) do
      [{Frameshift.Library, data_dir: Frameshift.Paths.data_dir()}]
    else
      []
    end
  end

  defp renderer_children do
    if Application.fetch_env!(:frameshift_core, :start_renderer) do
      [{Frameshift.Renderer, path: Application.fetch_env!(:frameshift_core, :renderer_path)}]
    else
      []
    end
  end

  defp metrics_children do
    if Application.fetch_env!(:frameshift_core, :start_library) do
      [Metrics]
    else
      []
    end
  end

  defp local_ipc_children do
    if Application.fetch_env!(:frameshift_core, :start_local_ipc) do
      token_path =
        System.get_env("FRAMESHIFT_IPC_TOKEN_FILE") ||
          raise "FRAMESHIFT_IPC_TOKEN_FILE is required when local IPC is enabled"

      token =
        case Token.consume(token_path) do
          {:ok, token} -> token
          {:error, reason} -> raise "could not consume local IPC bootstrap token: #{reason}"
        end

      configure_credential_broker(token)

      [
        {Frameshift.LocalIPC.Server, path: Frameshift.Paths.socket_path(), token: token},
        {DiagnosticsServer, path: Frameshift.Paths.diagnostics_socket_path()}
      ]
    else
      []
    end
  end

  defp configure_credential_broker(token) do
    case System.get_env("FRAMESHIFT_CREDENTIAL_SOCKET") do
      nil ->
        :ok

      path ->
        expanded = Path.expand(path)

        with true <- Path.dirname(expanded) == Path.dirname(Frameshift.Paths.socket_path()),
             {:ok, %File.Stat{type: :other, mode: mode, uid: uid}} <- File.lstat(expanded),
             {:ok, %File.Stat{type: :directory, uid: ^uid, mode: directory_mode}} <-
               File.lstat(Path.dirname(expanded)),
             true <-
               Bitwise.band(mode, 0o077) == 0 and
                 Bitwise.band(directory_mode, 0o077) == 0 do
          Application.put_env(:frameshift_core, :direct_delivery,
            credential_resolver: {KeychainBroker, %{socket_path: expanded, token: token}}
          )
        else
          _invalid -> raise "credential broker socket failed local admission"
        end
    end
  end
end
