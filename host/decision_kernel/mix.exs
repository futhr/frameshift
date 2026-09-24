defmodule FrameshiftDecisions.MixProject do
  use Mix.Project

  def project do
    [
      app: :frameshift_decisions,
      version: "0.1.0",
      compilers: [:gleam, :app],
      deps: []
    ]
  end

  def application, do: [extra_applications: []]
end

defmodule Mix.Tasks.Compile.Gleam do
  use Mix.Task

  @root __DIR__
  @source Path.join(@root, "build/dev/erlang/frameshift_decisions/ebin/frameshift_decisions.beam")

  def run(_) do
    executable = System.find_executable("gleam") || Mix.raise("Gleam is required")

    {output, status} =
      System.cmd(executable, ["build", "--target", "erlang", "--warnings-as-errors"],
        cd: @root,
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("Gleam build failed:\n#{output}")

    destination = Path.join(Mix.Project.compile_path(), "frameshift_decisions.beam")
    File.mkdir_p!(Path.dirname(destination))
    File.cp!(@source, destination)
    {:ok, []}
  end
end
