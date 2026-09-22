defmodule Frameshift.Paths do
  @moduledoc false

  @spec data_dir() :: String.t()
  def data_dir do
    case System.get_env("FRAMESHIFT_DATA_DIR") do
      nil -> :filename.basedir(:user_data, "Frameshift")
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
end
