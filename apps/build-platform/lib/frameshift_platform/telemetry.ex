defmodule FrameshiftPlatform.Telemetry do
  @moduledoc "Versioned low-cardinality server metrics; no domain identifiers in labels."

  import Telemetry.Metrics

  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics do
    [
      counter("frameshift_platform.catalog.source.count",
        event_name: [:frameshift_platform, :catalog, :source, :stop],
        tags: [:outcome],
        tag_values: &source_tags/1
      ),
      distribution("frameshift_platform.http.duration.seconds",
        event_name: [:frameshift_platform, :endpoint, :stop],
        measurement: :duration,
        unit: {:native, :second},
        reporter_options: [buckets: [0.01, 0.05, 0.1, 0.5, 1, 5]]
      ),
      last_value("vm.memory.total", unit: :byte)
    ]
  end

  @spec source_tags(map()) :: map()
  def source_tags(%{outcome: outcome}) when outcome in [:ok, :error], do: %{outcome: outcome}
  def source_tags(_), do: %{outcome: :other}
end
