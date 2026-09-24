defmodule Frameshift.Diagnostics.FallbackLogTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Diagnostics.FallbackLog

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-fallback-log-#{System.unique_integer([:positive, :monotonic])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root}
  end

  test "prepares a private directory and restricts an existing regular log", %{root: root} do
    path = Path.join(root, "diagnostics/core-fallback.log")
    assert :ok = FallbackLog.prepare(path)
    assert Bitwise.band(File.lstat!(Path.dirname(path)).mode, 0o077) == 0

    File.write!(path, "prior sanitized record")
    File.chmod!(path, 0o666)
    assert :ok = FallbackLog.prepare(path)
    assert Bitwise.band(File.lstat!(path).mode, 0o777) == 0o600
  end

  test "refuses a symlinked diagnostics directory without changing its target", %{root: root} do
    target = Path.join(root, "target")
    File.mkdir_p!(target)
    File.chmod!(target, 0o755)
    File.ln_s!(target, Path.join(root, "diagnostics"))

    assert {:error, :unsafe_fallback_log} =
             FallbackLog.prepare(Path.join(root, "diagnostics/core-fallback.log"))

    assert Bitwise.band(File.lstat!(target).mode, 0o777) == 0o755
  end

  test "refuses a symlinked log without changing its target", %{root: root} do
    directory = Path.join(root, "diagnostics")
    File.mkdir_p!(directory)
    target = Path.join(root, "unrelated")
    File.write!(target, "keep")
    File.ln_s!(target, Path.join(directory, "core-fallback.log"))

    assert {:error, :unsafe_fallback_log} =
             FallbackLog.prepare(Path.join(directory, "core-fallback.log"))

    assert File.read!(target) == "keep"
  end

  test "refuses a non-regular log target", %{root: root} do
    path = Path.join(root, "diagnostics/core-fallback.log")
    File.mkdir_p!(path)
    assert {:error, :unsafe_fallback_log} = FallbackLog.prepare(path)
  end
end
