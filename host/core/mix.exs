defmodule FrameshiftCore.MixProject do
  @moduledoc false

  use Mix.Project

  @source_url "https://github.com/wotex-project/frameshift"
  @wotex_ref "e6aa01a69ea35447afa989d5dea061618d20b3cf"

  def project do
    [
      app: :frameshift_core,
      version: "0.1.0-dev",
      elixir: "~> 1.20 and >= 1.20.2",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      docs: docs(),
      elixirc_options: [warnings_as_errors: true],
      name: "Frameshift Core",
      source_url: @source_url,
      homepage_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :logger, :ssl],
      mod: {Frameshift.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test,
        doctor: :test,
        dialyzer: :test
      ]
    ]
  end

  defp deps do
    [
      {:exqlite, "~> 0.40.0"},
      {:telemetry, "~> 1.4"},
      {:telemetry_metrics, "~> 1.1"},
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
      {:benchee, "~> 1.5", only: :dev, runtime: false},
      {:benchee_markdown, "~> 0.3.4", only: :dev, runtime: false},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.8", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: [:dev, :test, :docs], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.3", only: :test}
    ]
  end

  defp aliases do
    [
      bench: ["run --no-start bench/protocol_bench.exs"],
      lint: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end

  defp description do
    "Durable, vendor-neutral host runtime for universal Frameshift devices"
  end

  defp docs do
    [
      main: "readme",
      extras:
        [
          {"README.md", title: "Core overview"},
          {"../../docs/architecture/system.md", title: "System architecture"},
          {"../../docs/architecture/host-core.md", title: "Portable host core"},
          {"../../docs/architecture/library-backup.md", title: "Library backup and restore"},
          {"../../docs/architecture/container-frame-simulator.md",
           title: "Networked frame simulator"},
          {"../../docs/hardware/validation-plan.md", title: "Hardware validation plan"},
          {"../../docs/architecture/domain-map.md", title: "Host domain map"},
          {"../../docs/architecture/qualified-generations.md", title: "Qualified generations"},
          {"../../docs/architecture/diagnostics.md", title: "Host diagnostics"},
          {"../../docs/architecture/frame-protocol.md", title: "Frame protocol"},
          {"../../docs/architecture/display-timing.md", title: "Display timing"},
          {"../../docs/architecture/verification.md", title: "Verification map"},
          {"../../docs/research/software-stack.md", title: "Software stack research"},
          {"../../docs/research/protocol-foundations.md", title: "Protocol foundations"}
        ] ++ Path.wildcard("bench/output/*.md"),
      groups_for_extras: [
        Architecture: ~r/docs\/architecture/,
        Benchmarks: ~r/bench\/output/
      ],
      source_url: @source_url,
      formatters: ["html"]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_file: {:no_warn, "priv/plts/frameshift_core.plt"},
      flags: [:error_handling, :missing_return]
    ]
  end
end
