defmodule Frameshift.Diagnostics.StoreTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Diagnostics.Store
  alias Frameshift.Digest

  test "audit persistence keeps only approved detail fields" do
    {:ok, connection} = Exqlite.start_link(database: ":memory:")
    Process.unlink(connection)

    on_exit(fn -> if Process.alive?(connection), do: GenServer.stop(connection) end)

    Exqlite.query!(
      connection,
      """
      CREATE TABLE audit_entries (
        id INTEGER PRIMARY KEY, operation TEXT, subject_digest TEXT,
        detail_json TEXT, occurred_at_ms INTEGER, correlation_id TEXT, attempt_id TEXT
      )
      """
    )

    :ok =
      Store.record_audit(connection, "command.completed", nil, %{
        "commandId" => "private-command",
        "frameId" => "private-frame",
        "secret" => "private-token",
        "kind" => "succeeded",
        "attemptId" => String.duplicate("a", 32)
      })

    assert %Exqlite.Result{rows: [[details_json, correlation_id, attempt_id]]} =
             Exqlite.query!(
               connection,
               "SELECT detail_json, correlation_id, attempt_id FROM audit_entries"
             )

    assert Jason.decode!(details_json) == %{"kind" => "succeeded"}
    assert correlation_id == Digest.sha256("private-command")
    assert attempt_id == String.duplicate("a", 32)

    :ok =
      Store.record_audit(connection, "command.completed", nil, %{
        "kind" => "token=private",
        "outcome" => "token=private",
        "sourceKind" => "token=private",
        "revision" => "token=private",
        "attemptId" => "token=private"
      })

    assert %Exqlite.Result{rows: [["{}", nil]]} =
             Exqlite.query!(
               connection,
               "SELECT detail_json, attempt_id FROM audit_entries ORDER BY id DESC LIMIT 1"
             )
  end

  test "metric maintenance removes the oldest rows beyond its capacity" do
    {:ok, connection} = Exqlite.start_link(database: ":memory:")
    Process.unlink(connection)
    on_exit(fn -> if Process.alive?(connection), do: GenServer.stop(connection) end)

    Exqlite.query!(
      connection,
      "CREATE TABLE metric_rollups (metric TEXT, bucket_ms INTEGER, granularity TEXT)"
    )

    Exqlite.query!(
      connection,
      """
      WITH RECURSIVE sequence(value) AS (
        SELECT 0 UNION ALL SELECT value + 1 FROM sequence WHERE value < 20000
      )
      INSERT INTO metric_rollups(metric, bucket_ms, granularity)
      SELECT 'frameshift.test', value, 'hour' FROM sequence
      """
    )

    assert :ok = Store.merge_rollups(connection, [], 0)

    assert %Exqlite.Result{rows: [[20_000, 1]]} =
             Exqlite.query!(connection, "SELECT count(*), min(bucket_ms) FROM metric_rollups")
  end
end
