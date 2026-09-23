defmodule Frameshift.Diagnostics.MetricsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Frameshift.Diagnostics.Metrics
  alias Frameshift.Library

  test "retains a metric batch across a SQLite owner restart" do
    root = "/tmp/fs-metrics-#{System.unique_integer([:positive, :monotonic])}"
    library_name = {:global, {:frameshift_metrics_test, root}}
    {:ok, library} = Library.start_link(data_dir: root, name: library_name)
    {:ok, collector} = Metrics.start_link(library: library_name, name: nil)

    on_exit(fn ->
      if Process.alive?(collector), do: GenServer.stop(collector)
      File.rm_rf!(root)
    end)

    :telemetry.execute(
      [:frameshift, :render, :completed],
      %{duration_ms: 42},
      %{outcome: :succeeded}
    )

    GenServer.stop(library)
    assert {:error, _} = Metrics.flush(collector)
    assert Metrics.status(collector)["flushFailures"] == 1
    assert Metrics.status(collector)["pendingSeries"] == 2

    {:ok, restarted} = Library.start_link(data_dir: root, name: library_name)
    on_exit(fn -> if Process.alive?(restarted), do: GenServer.stop(restarted) end)

    assert :ok = Metrics.flush(collector)
    assert Metrics.status(collector)["pendingSeries"] == 0

    assert %{"entries" => entries} = Library.metric_page(restarted)
    assert Enum.count(entries, &(&1["metric"] == "frameshift.render.duration.ms")) == 2
  end
end
