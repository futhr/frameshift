defmodule FrameshiftCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :frameshift_core,
      version: "0.1.0-dev",
      elixir: "~> 1.20 and >= 1.20.2",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_options: [warnings_as_errors: true],
      test_coverage: [summary: [threshold: 80]],
      dialyzer: [plt_file: {:no_warn, "priv/plts/frameshift_core.plt"}]
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :logger],
      mod: {Frameshift.Application, []}
    ]
  end

  def cli do
    [preferred_envs: [check: :test, lint: :test]]
  end

  defp deps do
    [
      {:exqlite, "~> 0.40.0"},
      {:jsv, "~> 0.22.0"},
      {:rfc8785, "~> 1.0.0"},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.8", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      check: ["lint", "test --cover"],
      lint: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end
end
