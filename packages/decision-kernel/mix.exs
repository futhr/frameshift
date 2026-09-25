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
  @ebin Path.join(@root, "build/dev/erlang/frameshift_decisions/ebin")
  @stdlib Path.join(@root, "build/dev/erlang/gleam_stdlib/ebin")

  def run(_) do
    executable = System.find_executable("gleam") || Mix.raise("Gleam is required")

    {output, status} =
      System.cmd(executable, ["build", "--target", "erlang", "--warnings-as-errors"],
        cd: @root,
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("Gleam build failed:\n#{output}")

    File.mkdir_p!(Mix.Project.compile_path())

    Mix.Project.compile_path()
    |> Path.join("*.beam")
    |> Path.wildcard()
    |> Enum.each(&File.rm!/1)

    @root
    |> Path.join("src/**/*.gleam")
    |> Path.wildcard()
    |> Enum.each(&copy_module/1)

    @stdlib
    |> Path.join("*.beam")
    |> Path.wildcard()
    |> Enum.each(&File.cp!(&1, Path.join(Mix.Project.compile_path(), Path.basename(&1))))

    {:ok, []}
  end

  defp copy_module(source) do
    beam =
      source
      |> Path.relative_to(Path.join(@root, "src"))
      |> Path.rootname()
      |> String.replace("/", "@")
      |> Kernel.<>(".beam")

    File.cp!(Path.join(@ebin, beam), Path.join(Mix.Project.compile_path(), beam))
  end
end
