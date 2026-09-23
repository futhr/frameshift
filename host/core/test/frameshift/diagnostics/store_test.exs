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
        "attemptId" => "random-attempt"
      })

    assert %Exqlite.Result{rows: [[details_json, correlation_id, attempt_id]]} =
             Exqlite.query!(
               connection,
               "SELECT detail_json, correlation_id, attempt_id FROM audit_entries"
             )

    assert Jason.decode!(details_json) == %{"kind" => "succeeded"}
    assert correlation_id == Digest.sha256("private-command")
    assert attempt_id == "random-attempt"
  end
end
