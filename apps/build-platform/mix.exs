defmodule FrameshiftPlatform.MixProject do
  @moduledoc false

  use Mix.Project

  def project do
    [
      app: :frameshift_platform,
      version: "0.1.0-dev",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      elixirc_options: [warnings_as_errors: true],
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [mod: {FrameshiftPlatform.Application, []}, extra_applications: [:logger, :crypto]]
  end

  def cli, do: [preferred_envs: [check: :test]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:frameshift_decisions, path: "../../packages/decision-kernel"},
      {:phoenix, "~> 1.8.14"},
      {:phoenix_assets, "~> 1.1.1"},
      {:ash, "~> 3.33.9"},
      {:ash_postgres, "~> 2.13.1"},
      {:simple_sat, "~> 0.1"},
      {:postgrex, "~> 0.22"},
      {:bandit, "~> 1.12"},
      {:jason, "~> 1.4"},
      {:beamlens, "~> 0.3.1"},
      {:req, "~> 0.6"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_metrics_prometheus_core, "~> 1.2.1"},
      {:telemetry_poller, "~> 1.3"},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.3"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "credo --strict"
      ]
    ]
  end
end
