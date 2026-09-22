defmodule FrameshiftCore.MixProject do
  use Mix.Project

  @wotex_ref "e6aa01a69ea35447afa989d5dea061618d20b3cf"

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
      {:mint, "~> 1.10"},
      {:wotex,
       git: "https://github.com/wotex-project/wotex.git",
       ref: @wotex_ref,
       sparse: "packages/wotex",
       override: true},
      {:wotex_binding_http,
       git: "https://github.com/wotex-project/wotex.git",
       ref: @wotex_ref,
       sparse: "packages/wotex-binding-http"},
      {:wotex_runtime,
       git: "https://github.com/wotex-project/wotex.git",
       ref: @wotex_ref,
       sparse: "packages/wotex-runtime",
       override: true},
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
