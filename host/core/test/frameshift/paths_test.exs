defmodule Frameshift.PathsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Frameshift.Paths

  test "release paths resolve defaults and relocatable overrides" do
    previous_data = System.get_env("FRAMESHIFT_DATA_DIR")
    previous_socket = System.get_env("FRAMESHIFT_SOCKET_PATH")

    on_exit(fn ->
      restore("FRAMESHIFT_DATA_DIR", previous_data)
      restore("FRAMESHIFT_SOCKET_PATH", previous_socket)
    end)

    System.delete_env("FRAMESHIFT_DATA_DIR")
    System.delete_env("FRAMESHIFT_SOCKET_PATH")
    assert Paths.data_dir() == to_string(:filename.basedir(:user_data, "Frameshift"))
    assert Paths.socket_path() == Path.join(Paths.data_dir(), "core.sock")

    System.put_env("FRAMESHIFT_DATA_DIR", "relative/library")
    System.put_env("FRAMESHIFT_SOCKET_PATH", "relative/socket/core.sock")
    assert Paths.data_dir() == Path.expand("relative/library")
    assert Paths.socket_path() == Path.expand("relative/socket/core.sock")
  end

  defp restore(key, nil), do: System.delete_env(key)
  defp restore(key, value), do: System.put_env(key, value)
end
