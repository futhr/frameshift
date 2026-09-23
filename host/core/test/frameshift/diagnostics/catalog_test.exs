defmodule Frameshift.Diagnostics.CatalogTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Diagnostics.Catalog

  test "definitions and samples use bounded semantic dimensions" do
    definitions = Catalog.metrics()
    assert length(definitions) == 7
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
  end
end
