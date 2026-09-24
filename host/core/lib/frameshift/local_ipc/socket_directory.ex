defmodule Frameshift.LocalIPC.SocketDirectory do
  @moduledoc "Admits a private Unix-socket directory without following its final symlink."

  @spec prepare(String.t()) :: :ok | {:error, :socket_path_too_long | :unsafe_socket_directory}
  def prepare(path) when is_binary(path) do
    if byte_size(path) > 100 do
      {:error, :socket_path_too_long}
    else
      prepare_directory(Path.dirname(path))
    end
  end

  defp prepare_directory(parent) do
    with :ok <- File.mkdir_p(parent),
         {:ok, %File.Stat{type: :directory}} <- File.lstat(parent),
         :ok <- File.chmod(parent, 0o700),
         {:ok, %File.Stat{type: :directory, mode: mode}} <- File.lstat(parent),
         true <- Bitwise.band(mode, 0o077) == 0 do
      :ok
    else
      _ -> {:error, :unsafe_socket_directory}
    end
  end
end
