defmodule Frameshift.Paths do
  @moduledoc """
  Resolves relocatable core data and local IPC paths on macOS.

  Release configuration may override the Apple user-data default without
  embedding a build-machine or developer-home path in the application.
  """

  @spec data_dir() :: String.t()
  def data_dir do
    case System.get_env("FRAMESHIFT_DATA_DIR") do
      nil -> :filename.basedir(:user_data, "Frameshift") |> to_string()
      path -> Path.expand(path)
    end
  end

  @spec socket_path() :: String.t()
  def socket_path do
    case System.get_env("FRAMESHIFT_SOCKET_PATH") do
      nil -> Path.join(data_dir(), "core.sock")
      path -> Path.expand(path)
    end
  end

  @doc "Returns the read-only local diagnostics socket beside the command socket."
  @spec diagnostics_socket_path() :: String.t()
  def diagnostics_socket_path do
    case System.get_env("FRAMESHIFT_DIAGNOSTICS_SOCKET_PATH") do
      nil -> Path.join(Path.dirname(socket_path()), "d.sock")
      path -> Path.expand(path)
    end
  end
end
