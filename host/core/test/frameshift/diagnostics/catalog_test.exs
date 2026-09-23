defmodule Frameshift.Diagnostics.CatalogTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Diagnostics.Catalog

  test "definitions and samples use bounded semantic dimensions" do
    definitions = Catalog.metrics()
    assert length(definitions) == 11
    assert Enum.all?(definitions, &(&1.event_name in Catalog.events()))

    samples =
      Catalog.samples(
        [:frameshift, :command, :completed],
        %{count: 1, duration_ms: 42},
        %{outcome: "untrusted outcome", frame_id: "dynamic-secret"}
      )

    assert length(samples) == 2
    assert Enum.all?(samples, &(&1.dimensions == %{"outcome" => "other"}))
    refute Enum.any?(samples, &Map.has_key?(&1.dimensions, "frame_id"))
  end

  test "rejects negative, oversized, and non-numeric measurements" do
    event = [:frameshift, :render, :completed]
    assert Catalog.samples(event, %{duration_ms: -1}, %{outcome: :failed}) == []
    assert Catalog.samples(event, %{duration_ms: 1_000_000_000_001}, %{}) == []
    assert Catalog.samples(event, %{duration_ms: "private"}, %{}) == []
    assert Catalog.samples([:unknown], %{count: 1}, %{}) == []

    assert [%{dimensions: %{"outcome" => "other"}}] =
             Catalog.samples(event, %{duration_ms: 2}, %{outcome: %{unsafe: "value"}})
  end

  test "attempt metrics keep only bounded mode and outcome labels" do
    assert [%{dimensions: %{"mode" => "reconcile", "outcome" => "failed"}}] =
             Catalog.samples(
               [:frameshift, :delivery, :attempt],
               %{count: 1},
               %{mode: :reconcile, outcome: :failed, attempt_id: String.duplicate("a", 32)}
             )
  end

  test "qualification decisions retain only bounded stage and outcome labels" do
    assert [%{dimensions: %{"stage" => "cohort", "outcome" => "refused"}}] =
             Catalog.samples(
               [:frameshift, :qualification, :decision],
               %{count: 1},
               %{stage: :cohort, outcome: :refused, frame_id: "private-frame"}
             )

    assert [%{dimensions: %{"stage" => "other", "outcome" => "other"}}] =
             Catalog.samples(
               [:frameshift, :qualification, :decision],
               %{count: 1},
               %{stage: "private-stage", outcome: "private-outcome"}
             )
  end

  test "outbox metrics classify routes and outcomes without a frame or asset label" do
    assert [count, duration] =
             Catalog.samples(
               [:frameshift, :outbox, :exchange],
               %{count: 1, duration_ms: 17},
               %{
                 route: :asset,
                 outcome: :unavailable,
                 frame_id: "private-frame",
                 asset_digest: "private-digest"
               }
             )

    assert count.dimensions == %{"route" => "asset", "outcome" => "unavailable"}
    assert duration.dimensions == count.dimensions

    assert Enum.all?([count, duration], fn sample ->
             map_size(sample.dimensions) == 2
           end)
  end

  test "only catalog rollups with bounded dimensions and aligned buckets are valid" do
    rollup = %{
      metric: "frameshift.command.duration.ms",
      bucket_ms: 60_000,
      granularity: "minute",
      dimensions: %{"outcome" => "succeeded"},
      count: 2,
      sum: 100.0,
      min: 37.0,
      max: 63.0,
      histogram: List.replace_at(List.duplicate(0, 13), 3, 2)
    }

    assert Catalog.valid_rollup?(rollup)
    refute Catalog.valid_rollup?(%{rollup | bucket_ms: 61_000})
    refute Catalog.valid_rollup?(%{rollup | dimensions: %{"frameId" => "secret"}})
    refute Catalog.valid_rollup?(%{rollup | histogram: [2]})
    refute Catalog.valid_rollup?(%{rollup | count: -1})
    refute Catalog.valid_rollup?(Map.put(rollup, :metric, "invented"))
  end
end
