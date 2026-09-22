defmodule FrameshiftCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :frameshift_core,
      version: "0.1.0-dev",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_options: [warnings_as_errors: true],
      test_coverage: [summary: [threshold: 80]]
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :logger],
      mod: {Frameshift.Application, []}
    ]
  end

  defp deps do
    [
      {:jsv, "~> 0.22.0"}
    ]
  end

  defp aliases do
    [
      check: ["format --check-formatted", "compile --warnings-as-errors", "test"]
    ]
  end
end
