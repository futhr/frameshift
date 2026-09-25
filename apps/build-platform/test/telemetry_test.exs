defmodule FrameshiftPlatform.TelemetryTest do
  @moduledoc false

  use ExUnit.Case, async: false
  alias FrameshiftPlatform.Telemetry.Reporter
  import Phoenix.ConnTest
  @endpoint FrameshiftPlatformWeb.Endpoint
  @event [:frameshift_platform, :endpoint, :stop]
  @registry :frameshift_platform
  @histogram "frameshift_platform_http_duration_seconds"
  @counter "frameshift_platform_http_responses_total"

  setup do
    restart_reporter()
    :ok
  end

  test "100,000 concurrent observations aggregate without a scrape or sample retention" do
    before = storage()
    started = System.monotonic_time(:microsecond)

    1..20
    |> Task.async_stream(fn _ -> emit_batch(5_000) end, max_concurrency: 20, timeout: 30_000)
    |> Enum.each(fn result -> assert result == {:ok, :ok} end)

    elapsed = System.monotonic_time(:microsecond) - started
    after_load = storage()
    assert :prometheus_counter.value(@registry, @counter, [:sources, :success]) == 100_000
    {buckets, sum} = :prometheus_histogram.value(@registry, @histogram, [:sources, :success])
    assert Enum.sum(buckets) == 100_000
    assert_in_delta sum, 2_000, 0.001
    assert after_load.rows - before.rows <= 64
    assert after_load.bytes - before.bytes < 131_072
    assert {:message_queue_len, 0} = Process.info(Process.whereis(Reporter), :message_queue_len)
    assert {:ok, text} = Reporter.scrape()
    assert text =~ "# TYPE #{@histogram} histogram"
    refute text =~ "PRIVATE ARTWORK"

    IO.puts(
      "Telemetry load: #{elapsed} µs, #{after_load.bytes - before.bytes} added bytes, 100000 observations"
    )
  end

  test "unknown labels collapse and invalid measurements cannot detach the handler" do
    conn = %{Plug.Test.conn(:get, "/private-customer") | status: 777}

    for value <- [-1, 1.2, nil, "secret", %{}, System.convert_time_unit(86_401, :second, :native)] do
      :telemetry.execute(@event, %{duration: value}, %{conn: conn, secret: "PRIVATE ARTWORK"})
    end

    emit_batch(1)
    assert :prometheus_counter.value(@registry, @counter, [:other, :other]) == 6

    assert :prometheus_counter.value(
             @registry,
             "frameshift_platform_telemetry_rejected_total",
             []
           ) == 6

    assert :prometheus_histogram.value(@registry, @histogram, [:other, :other]) == :undefined
    assert {:ok, text} = Reporter.scrape()
    refute text =~ "private-customer"
    refute text =~ "PRIVATE ARTWORK"
    assert text =~ ~s(route="sources")
  end

  test "collector outage leaves HTTP available and restart marks a new interval" do
    emit_batch(1)

    started =
      :prometheus_gauge.value(@registry, "frameshift_platform_collector_started_seconds", [])

    Supervisor.terminate_child(FrameshiftPlatform.Supervisor, Reporter)
    on_exit(&ensure_reporter/0)
    assert {:error, :unavailable} = Reporter.scrape()
    assert %{"status" => "ok"} = build_conn() |> get("/api/health") |> json_response(200)
    :telemetry.execute(@event, %{duration: 1}, %{})

    assert {:ok, _} = Supervisor.restart_child(FrameshiftPlatform.Supervisor, Reporter)
    assert :prometheus_counter.value(@registry, @counter, [:sources, :success]) == :undefined

    assert :prometheus_gauge.value(@registry, "frameshift_platform_collector_started_seconds", []) >=
             started

    emit_batch(1)
    assert :prometheus_counter.value(@registry, @counter, [:sources, :success]) == 1
  end

  test "transport exception observations are scoped to this endpoint" do
    event = [:bandit, :request, :exception]
    :telemetry.execute(event, %{}, %{plug: {UnknownEndpoint, []}, exception: "secret"})
    :telemetry.execute(event, %{}, %{plug: {@endpoint, []}, exception: "secret"})

    assert :prometheus_counter.value(
             @registry,
             "frameshift_platform_http_transport_exceptions_total",
             [:other]
           ) == 1

    assert {:ok, text} = Reporter.scrape()
    refute text =~ "secret"
  end

  defp emit_batch(count) do
    duration = System.convert_time_unit(20, :millisecond, :native)
    conn = %{Plug.Test.conn(:get, "/api/sources") | status: 200, resp_body: "PRIVATE ARTWORK"}

    Enum.each(1..count, fn _ ->
      :telemetry.execute(@event, %{duration: duration}, %{conn: conn})
    end)
  end

  defp storage do
    Enum.reduce(
      [:prometheus_histogram_table, :prometheus_counter_table],
      %{rows: 0, bytes: 0},
      fn table, acc ->
        %{
          rows: acc.rows + :ets.info(table, :size),
          bytes: acc.bytes + :ets.info(table, :memory) * :erlang.system_info(:wordsize)
        }
      end
    )
  end

  defp restart_reporter do
    :ok = Supervisor.terminate_child(FrameshiftPlatform.Supervisor, Reporter)
    {:ok, _} = Supervisor.restart_child(FrameshiftPlatform.Supervisor, Reporter)
  end

  defp ensure_reporter do
    if is_nil(Process.whereis(Reporter)),
      do: Supervisor.restart_child(FrameshiftPlatform.Supervisor, Reporter)
  end
end
