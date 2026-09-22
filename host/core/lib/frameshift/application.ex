defmodule Frameshift.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Task.Supervisor, name: Frameshift.TaskSupervisor}
      ] ++ library_children()

    Supervisor.start_link(children, strategy: :one_for_one, name: Frameshift.Supervisor)
  end

  defp library_children do
    if Application.fetch_env!(:frameshift_core, :start_library) do
      [{Frameshift.Library, data_dir: Frameshift.Paths.data_dir()}]
    else
      []
    end
  end
end
