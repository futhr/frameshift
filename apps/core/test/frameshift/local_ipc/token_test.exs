defmodule Frameshift.LocalIPC.TokenTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.LocalIPC.Token

  test "consumes one user-only bootstrap token exactly once" do
    root = temporary_root()
    path = Path.join(root, "bootstrap-token")
    token = String.duplicate("a", 64)
    File.write!(path, token, [:binary, :exclusive])
    File.chmod!(path, 0o600)

    assert {:ok, ^token} = Token.consume(path)
    refute File.exists?(path)
    assert {:error, :enoent} = Token.consume(path)
  end

  test "rejects broad permissions and malformed token bytes" do
    root = temporary_root()
    broad = Path.join(root, "broad")
    malformed = Path.join(root, "malformed")
    File.write!(broad, String.duplicate("b", 64))
    File.chmod!(broad, 0o644)
    File.write!(malformed, String.duplicate("X", 64))
    File.chmod!(malformed, 0o600)

    assert {:error, :unsafe_token_permissions} = Token.consume(broad)
    refute File.exists?(broad)
    assert {:error, :invalid_ipc_token} = Token.consume(malformed)
    refute File.exists?(malformed)
  end

  defp temporary_root do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-token-test-#{System.unique_integer([:positive, :monotonic])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    root
  end
end
