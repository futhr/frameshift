defmodule Frameshift.Diagnostics.Store do
  @moduledoc """
  Read-only diagnostic projections and bounded rollup persistence.

  Called only by the library's single SQLite owner. This module does not own
  a connection or expose it to IPC clients.
  """

  @audit_detail_keys ~w(kind revision sourceKind)
  @maximum_page 100
  @maximum_rows 20_000

  @doc "Returns a descending, stable audit page with private fields removed."
  @spec audit_page(pid(), non_neg_integer() | nil, pos_integer()) ::
          map() | {:error, :invalid_diagnostics_query}
  def audit_page(connection, cursor, limit)
      when (is_nil(cursor) or (is_integer(cursor) and cursor >= 0)) and is_integer(limit) and
             limit in 1..@maximum_page do
    result =
      Exqlite.query!(
        connection,
        """
        SELECT id, operation, detail_json, correlation_id, attempt_id, occurred_at_ms
        FROM audit_entries
        WHERE (? IS NULL OR id < ?)
        ORDER BY id DESC LIMIT ?
        """,
        [cursor, cursor, limit + 1]
      )

    rows = Enum.take(result.rows, limit)

    entries =
      Enum.map(rows, fn [id, operation, details_json, correlation_id, attempt_id, occurred_at_ms] ->
        details =
          details_json
          |> Jason.decode!()
          |> Map.take(@audit_detail_keys)

        %{
          "id" => id,
          "operation" => operation,
          "detail" => details,
          "correlationId" => correlation_id,
          "attemptId" => attempt_id,
          "occurredAtMs" => occurred_at_ms
        }
      end)

    has_more = length(result.rows) > limit

    %{
      "entries" => entries,
      "nextCursor" => if(has_more, do: List.last(entries)["id"], else: nil),
      "hasMore" => has_more
    }
  end

  def audit_page(_connection, _cursor, _limit), do: {:error, :invalid_diagnostics_query}

  @doc "Returns a bounded recent metric page from committed rollups."
  @spec metric_page(pid(), non_neg_integer() | nil, pos_integer()) :: map() | {:error, atom()}
  def metric_page(connection, cursor, limit)
      when (is_nil(cursor) or (is_integer(cursor) and cursor >= 0)) and is_integer(limit) and
             limit in 1..@maximum_page do
    result =
      Exqlite.query!(
        connection,
        """
        SELECT rowid, metric, bucket_ms, granularity, dimensions_json,
               sample_count, value_sum, value_min, value_max, histogram_json
        FROM metric_rollups
        WHERE (? IS NULL OR rowid < ?)
        ORDER BY rowid DESC LIMIT ?
        """,
        [cursor, cursor, limit + 1]
      )

    entries =
      result.rows
      |> Enum.take(limit)
      |> Enum.map(fn [
                       id,
                       metric,
                       bucket_ms,
                       granularity,
                       dimensions_json,
                       count,
                       sum,
                       min,
                       max,
                       histogram_json
                     ] ->
        %{
          "id" => id,
          "metric" => metric,
          "bucketMs" => bucket_ms,
          "granularity" => granularity,
          "dimensions" => Jason.decode!(dimensions_json),
          "count" => count,
          "sum" => sum,
          "min" => min,
          "max" => max,
          "histogram" => Jason.decode!(histogram_json)
        }
      end)

    has_more = length(result.rows) > limit

    %{
      "entries" => entries,
      "nextCursor" => if(has_more, do: List.last(entries)["id"], else: nil),
      "hasMore" => has_more
    }
  end

  def metric_page(_connection, _cursor, _limit), do: {:error, :invalid_diagnostics_query}

  @doc "Returns small, identifier-free gauges from authoritative state."
  @spec health(pid()) :: map()
  def health(connection) do
    counts =
      Exqlite.query!(
        connection,
        """
        SELECT
          (SELECT count(*) FROM frame_outboxes),
          (SELECT count(*) FROM frame_direct_deliveries WHERE status = 'pending'),
          (SELECT count(*) FROM command_receipts WHERE status = 'pending'),
          (SELECT count(*) FROM audit_entries),
          (SELECT count(*) FROM metric_rollups)
        """
      ).rows

    [[outboxes, direct_pending, command_pending, audit_count, metric_count]] = counts

    %{
      "pendingPull" => outboxes,
      "pendingPush" => direct_pending,
      "unknownCommands" => command_pending,
      "auditEntries" => audit_count,
      "metricRollups" => metric_count
    }
  end

  @doc "Merges a bounded batch of completed metric buckets under the caller's transaction."
  @spec merge_rollups(pid(), [map()], non_neg_integer()) :: :ok
  def merge_rollups(connection, rows, now_ms) when is_list(rows) and length(rows) <= 2_000 do
    Enum.each(rows, &merge_rollup(connection, &1))

    Exqlite.query!(
      connection,
      "DELETE FROM metric_rollups WHERE (granularity = 'minute' AND bucket_ms < ?) OR (granularity = 'hour' AND bucket_ms < ?)",
      [now_ms - 86_400_000, now_ms - 2_592_000_000]
    )

    count =
      connection
      |> Exqlite.query!("SELECT count(*) FROM metric_rollups")
      |> Map.fetch!(:rows)
      |> then(fn [[value]] -> value end)

    if count > @maximum_rows do
      Exqlite.query!(
        connection,
        "DELETE FROM metric_rollups WHERE rowid IN (SELECT rowid FROM metric_rollups ORDER BY bucket_ms ASC, rowid ASC LIMIT ?)",
        [count - @maximum_rows]
      )
    end

    :ok
  end

  defp merge_rollup(connection, row) do
    dimensions_json = RFC8785.encode!(row.dimensions)

    existing =
      Exqlite.query!(
        connection,
        """
        SELECT sample_count, value_sum, value_min, value_max, histogram_json
        FROM metric_rollups
        WHERE metric = ? AND bucket_ms = ? AND granularity = ? AND dimensions_json = ?
        """,
        [row.metric, row.bucket_ms, row.granularity, dimensions_json]
      ).rows

    merged =
      case existing do
        [[count, sum, min, max, histogram_json]] ->
          %{
            count: count + row.count,
            sum: sum + row.sum,
            min: Kernel.min(min, row.min),
            max: Kernel.max(max, row.max),
            histogram: merge_histograms(Jason.decode!(histogram_json), row.histogram)
          }

        [] ->
          row
      end

    Exqlite.query!(
      connection,
      """
      INSERT INTO metric_rollups(
        metric, bucket_ms, granularity, dimensions_json, sample_count,
        value_sum, value_min, value_max, histogram_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(metric, bucket_ms, granularity, dimensions_json) DO UPDATE SET
        sample_count = excluded.sample_count,
        value_sum = excluded.value_sum,
        value_min = excluded.value_min,
        value_max = excluded.value_max,
        histogram_json = excluded.histogram_json
      """,
      [
        row.metric,
        row.bucket_ms,
        row.granularity,
        dimensions_json,
        merged.count,
        merged.sum,
        merged.min,
        merged.max,
        RFC8785.encode!(merged.histogram)
      ]
    )
  end

  defp merge_histograms(left, right) when length(left) == length(right) do
    Enum.zip_with(left, right, &(&1 + &2))
  end
end
