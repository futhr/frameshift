defmodule Frameshift.Diagnostics.Catalog do
  @moduledoc """
  Versioned, bounded metric definitions for the portable host.

  Correlation IDs and dynamic frame or content identifiers are deliberately
  absent from dimensions. Unknown enum values collapse to `other`.
  """

  @duration_buckets [5, 10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, 10_000, 30_000]

  @specs [
    %{
      name: "frameshift.command.completed.count",
      event: [:frameshift, :command, :completed],
      measure: :count,
      kind: :sum,
      unit: :count,
      dimensions: %{outcome: ~w(succeeded failed replay unknown other)},
      buckets: []
    },
    %{
      name: "frameshift.command.duration.ms",
      event: [:frameshift, :command, :completed],
      measure: :duration_ms,
      kind: :distribution,
      unit: :millisecond,
      dimensions: %{outcome: ~w(succeeded failed replay unknown other)},
      buckets: @duration_buckets
    },
    %{
      name: "frameshift.delivery.intent.count",
      event: [:frameshift, :delivery, :intent],
      measure: :count,
      kind: :sum,
      unit: :count,
      dimensions: %{mode: ~w(push pull other)},
      buckets: []
    },
    %{
      name: "frameshift.delivery.confirmed.duration.ms",
      event: [:frameshift, :delivery, :confirmed],
      measure: :duration_ms,
      kind: :distribution,
      unit: :millisecond,
      dimensions: %{mode: ~w(push pull other)},
      buckets: @duration_buckets
    },
    %{
      name: "frameshift.render.duration.ms",
      event: [:frameshift, :render, :completed],
      measure: :duration_ms,
      kind: :distribution,
      unit: :millisecond,
      dimensions: %{outcome: ~w(succeeded failed cache_hit other)},
      buckets: @duration_buckets
    },
    %{
      name: "frameshift.storage.transaction.duration.ms",
      event: [:frameshift, :storage, :transaction],
      measure: :duration_ms,
      kind: :distribution,
      unit: :millisecond,
      dimensions: %{outcome: ~w(succeeded failed other)},
      buckets: @duration_buckets
    },
    %{
      name: "frameshift.diagnostics.dropped.count",
      event: [:frameshift, :diagnostics, :dropped],
      measure: :count,
      kind: :sum,
      unit: :count,
      dimensions: %{signal: ~w(metric log other)},
      buckets: []
    }
  ]

  @doc "Returns all portable telemetry event names."
  @spec events() :: [list(atom())]
  def events, do: @specs |> Enum.map(& &1.event) |> Enum.uniq()

  @doc "Returns the Telemetry.Metrics definitions used by the local reporter."
  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics do
    Enum.map(@specs, fn spec ->
      options = [
        event_name: spec.event,
        measurement: spec.measure,
        tags: Map.keys(spec.dimensions),
        unit: spec.unit
      ]

      case spec.kind do
        :sum -> Telemetry.Metrics.sum(spec.name, options)
        :distribution -> Telemetry.Metrics.distribution(spec.name, options)
      end
    end)
  end

  @doc "Extracts finite, bounded samples and normalized dimensions from an event."
  @spec samples(list(atom()), map(), map()) :: [map()]
  def samples(event, measurements, metadata) when is_map(measurements) and is_map(metadata) do
    @specs
    |> Enum.filter(&(&1.event == event))
    |> Enum.flat_map(&sample_for(&1, measurements, metadata))
  end

  def samples(_event, _measurements, _metadata), do: []

  defp sample_for(spec, measurements, metadata) do
    value = Map.get(measurements, spec.measure)

    if valid_value?(value) do
      dimensions = Map.new(spec.dimensions, &dimension(&1, metadata))

      [
        %{
          metric: spec.name,
          value: value,
          dimensions: dimensions,
          buckets: spec.buckets
        }
      ]
    else
      []
    end
  end

  defp dimension({key, allowed}, metadata) do
    candidate = metadata |> Map.get(key, :other) |> to_string()
    {Atom.to_string(key), if(candidate in allowed, do: candidate, else: "other")}
  end

  defp valid_value?(value) when is_integer(value), do: value >= 0 and value <= 1_000_000_000_000

  defp valid_value?(value) when is_float(value) do
    value >= 0 and value <= 1_000_000_000_000
  end

  defp valid_value?(_value), do: false
end
