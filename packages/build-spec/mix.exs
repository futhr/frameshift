defmodule FrameshiftBuild.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :frameshift_build,
      version: "0.1.0",
      elixir: "~> 1.20",
      compilers: [:gleam_build_spec, :elixir, :app],
      elixirc_options: [warnings_as_errors: true],
      deps: [
        {:frameshift_decisions, path: "../decision-kernel"},
        {:credo, "1.7.19", only: [:dev, :test], runtime: false}
      ]
    ]
  end

  def application, do: [extra_applications: [:crypto]]
end

defmodule Mix.Tasks.Compile.GleamBuildSpec do
  @moduledoc false
  use Mix.Task

  @root __DIR__
  @generated Path.join(@root, "build/dev/erlang")

  def run(_) do
    executable = System.find_executable("gleam") || Mix.raise("Gleam is required")

    {output, status} =
      System.cmd(executable, ["build", "--target", "erlang", "--warnings-as-errors"],
        cd: @root,
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("BuildSpec Gleam build failed:\n#{output}")
    File.mkdir_p!(Mix.Project.compile_path())
    remove_generated_modules()
    Enum.each(Path.wildcard(Path.join(@root, "src/**/*.gleam")), &copy_source/1)
    Enum.each(Path.wildcard(Path.join(@generated, "gleam_json/ebin/*.beam")), &copy_beam/1)
    {:ok, []}
  end

  defp remove_generated_modules do
    Mix.Project.compile_path()
    |> Path.join("*.beam")
    |> Path.wildcard()
    |> Enum.reject(&String.starts_with?(Path.basename(&1), "Elixir."))
    |> Enum.each(&File.rm!/1)
  end

  defp copy_source(source) do
    beam =
      source
      |> Path.relative_to(Path.join(@root, "src"))
      |> Path.rootname()
      |> String.replace("/", "@")
      |> Kernel.<>(".beam")

    copy_beam(Path.join([@generated, "frameshift_build", "ebin", beam]))
  end

  defp copy_beam(source) do
    File.cp!(source, Path.join(Mix.Project.compile_path(), Path.basename(source)))
  end
end
