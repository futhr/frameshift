ExUnit.start()

defmodule Frameshift.TestSupport do
  @moduledoc false

  @spec stop_if_running(pid()) :: :ok
  def stop_if_running(process) do
    try do
      GenServer.stop(process)
    catch
      :exit, {:noproc, _} -> :ok
    end
  end
end

if System.get_env("FRAMESHIFT_CONTAINER_TESTS") != "1" do
  ExUnit.configure(exclude: [container: true])
end
