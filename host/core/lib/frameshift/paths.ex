defmodule Frameshift.Paths do
  @moduledoc false

  @spec data_dir() :: String.t()
  def data_dir do
    case System.get_env("FRAMESHIFT_DATA_DIR") do
      nil -> :filename.basedir(:user_data, "Frameshift")
      path -> Path.expand(path)
    end
  end
end
