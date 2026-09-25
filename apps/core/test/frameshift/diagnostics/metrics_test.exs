defmodule Frameshift.Diagnostics.MetricsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Frameshift.Diagnostics.Metrics
  alias Frameshift.Library

  test "telemetry handler queues only bounded catalog samples" do
    dropped = :atomics.new(1, signed: false)
    queued = :atomics.new(1, signed: false)
    private_value = String.duplicate("private", 10_000)

    assert :ok =
             Metrics.handle_event(
               [:frameshift, :command, :completed],
               %{count: 1, duration_ms: 42, payload: private_value},
               %{outcome: private_value, command_id: private_value},
               %{target: self(), dropped: dropped, queued: queued, queue_limit: 10_000}
             )

    assert_receive {:samples, samples}
    assert length(samples) == 2
    assert Enum.all?(samples, &(&1.dimensions == %{"outcome" => "other"}))
    refute inspect(samples) =~ "private"
    assert :atomics.get(dropped, 1) == 0
    assert :atomics.get(queued, 1) == 1
  end

  test "telemetry handler reports loss when all queue slots are reserved" do
    dropped = :atomics.new(1, signed: false)
    queued = :atomics.new(1, signed: false)
    :atomics.put(queued, 1, 8)

    assert :ok =
             Metrics.handle_event(
               [:frameshift, :delivery, :attempt],
               %{count: 1},
               %{mode: :push, outcome: :failed},
               %{target: self(), dropped: dropped, queued: queued, queue_limit: 8}
             )

    assert :atomics.get(dropped, 1) == 1
    assert :atomics.get(queued, 1) == 8
    refute_receive {:samples, _}
  end

  test "concurrent emitters cannot reserve more than the queue limit" do
    dropped = :atomics.new(1, signed: false)
    queued = :atomics.new(1, signed: false)
    context = %{target: self(), dropped: dropped, queued: queued, queue_limit: 8}

    1..256
    |> Task.async_stream(
      fn _ ->
        Metrics.handle_event(
          [:frameshift, :delivery, :attempt],
          %{count: 1},
          %{mode: :push, outcome: :failed},
          context
        )
      end,
      max_concurrency: 32
    )
    |> Enum.each(fn {:ok, :ok} -> :ok end)

    assert :atomics.get(queued, 1) == 8
    assert :atomics.get(dropped, 1) == 248
    assert length(Process.info(self(), :messages) |> elem(1)) == 8
  end

  test "retains a metric batch across a SQLite owner restart" do
    root = "/tmp/fs-metrics-#{System.unique_integer([:positive, :monotonic])}"
    library_name = {:global, {:frameshift_metrics_test, root}}
    {:ok, library} = Library.start_link(data_dir: root, name: library_name)
    {:ok, collector} = Metrics.start_link(library: library_name, name: nil)

    on_exit(fn ->
      Frameshift.TestSupport.stop_if_running(collector)
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
    on_exit(fn -> Frameshift.TestSupport.stop_if_running(restarted) end)

    assert :ok = Metrics.flush(collector)
    assert Metrics.status(collector)["pendingSeries"] == 0

    assert %{"entries" => entries} = Library.metric_page(restarted)
    assert Enum.count(entries, &(&1["metric"] == "frameshift.render.duration.ms")) == 2
  end

  test "collector prunes existing stale rollups on an idle restart" do
    root = "/tmp/fs-metrics-maintenance-#{System.unique_integer([:positive, :monotonic])}"

    {:ok, initial} = Library.start_link(data_dir: root, name: nil)
    GenServer.stop(initial)

    {:ok, writer} = Exqlite.start_link(database: Path.join(root, "metadata.sqlite"))

    Exqlite.query!(
      writer,
      """
      INSERT INTO metric_rollups(
        metric, bucket_ms, granularity, dimensions_json, sample_count,
        value_sum, value_min, value_max, histogram_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      """,
      [
        "frameshift.render.duration.ms",
        0,
        "minute",
        "{\"outcome\":\"succeeded\"}",
        1,
        42.0,
        42.0,
        42.0,
        "[1]"
      ]
    )

    GenServer.stop(writer)

    {:ok, library} = Library.start_link(data_dir: root, name: nil)
    {:ok, collector} = Metrics.start_link(library: library, name: nil)

    on_exit(fn ->
      stop_if_alive(collector)
      stop_if_alive(library)
      File.rm_rf!(root)
    end)

    assert Metrics.status(collector)["flushFailures"] == 0
    assert %{"entries" => []} = Library.metric_page(library)
  end

  defp stop_if_alive(process) do
    if Process.alive?(process), do: GenServer.stop(process)
  catch
    :exit, _ -> :ok
  end
end
