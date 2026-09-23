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
             "durationMs" => 17
           } = decode(line)

    assert correlation_id == Frameshift.Digest.sha256("bad\ncommand")
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

  defp decode("FSLOG|" <> json), do: Jason.decode!(json)
end
