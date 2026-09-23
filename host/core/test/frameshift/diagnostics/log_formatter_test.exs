defmodule Frameshift.Diagnostics.LogFormatterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Diagnostics.LogFormatter

  test "emits an allowlisted structured record without source text or private metadata" do
    line =
      LogFormatter.format(:info, "secret-token=do-not-log", nil,
        frameshift_event: :command_completed,
        frameshift_outcome: :succeeded,
        request_id: "safe-request_1",
        command_id: "bad\ncommand",
        attempt_id: String.duplicate("b", 32),
        duration_ms: 17,
        path: "/private/artwork.png"
      )
      |> IO.iodata_to_binary()

    assert String.starts_with?(line, "FSLOG|")
    refute String.contains?(line, "secret-token")
    refute String.contains?(line, "/private/")
    refute String.contains?(line, "bad\\ncommand")

    assert %{
             "event" => "command_completed",
             "outcome" => "succeeded",
             "correlationId" => correlation_id,
             "attemptId" => attempt_id,
             "durationMs" => 17
           } = decode(line)

    assert correlation_id == Frameshift.Digest.sha256("bad\ncommand")
    assert attempt_id == String.duplicate("b", 32)
  end

  test "reduces arbitrary runtime errors to safe level and time" do
    line =
      LogFormatter.format(
        %{level: :error, msg: "secret", meta: %{path: "/Users/private"}},
        %{}
      )
      |> IO.iodata_to_binary()

    assert %{"event" => "runtime", "level" => "error", "timeMs" => time} = decode(line)
    assert is_integer(time)
    refute String.contains?(line, "secret")
    refute String.contains?(line, "/Users/")
    assert :ok = LogFormatter.check_config(%{})
  end

  test "rejects untrusted attempt IDs from public log fields" do
    line =
      LogFormatter.format(:info, "private", nil,
        frameshift_event: :delivery_attempt,
        frameshift_outcome: :pending,
        attempt_id: "secret-attempt-id"
      )
      |> IO.iodata_to_binary()

    assert %{"event" => "delivery_attempt", "outcome" => "pending"} = decode(line)
    refute String.contains?(line, "secret-attempt-id")
  end

  defp decode("FSLOG|" <> json), do: Jason.decode!(json)
end
