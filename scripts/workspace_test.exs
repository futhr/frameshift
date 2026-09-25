Code.require_file("workspace.exs", __DIR__)
ExUnit.start()

defmodule FrameshiftWorkspaceTest do
  use ExUnit.Case, async: true

  setup do
    root =
      Path.join(System.tmp_dir!(), "frameshift-workspace-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    components = [
      %{
        "name" => "core",
        "root" => "apps/core",
        "modules" => ["Frameshift"],
        "depends_on" => ["decisions"],
        "planned" => true
      },
      %{
        "name" => "platform",
        "root" => "apps/platform",
        "modules" => ["FrameshiftPlatform"],
        "depends_on" => ["decisions"],
        "planned" => true
      },
      %{
        "name" => "decisions",
        "root" => "packages/decisions",
        "modules" => ["frameshift_decisions"],
        "depends_on" => [],
        "planned" => true
      }
    ]

    %{root: root, components: components}
  end

  test "allows shared decisions without coupling the applications", context do
    assert inspect_source(
             context,
             "apps/core/lib/sample.ex",
             "defmodule Frameshift.Sample do\n def run, do: :frameshift_decisions.run()\nend"
           ) == []

    assert inspect_source(
             context,
             "apps/platform/lib/sample.ex",
             "defmodule FrameshiftPlatform.Sample do\n def run, do: :frameshift_decisions.run()\nend"
           ) == []
  end

  test "rejects cross-application aliases and fully qualified calls", context do
    for source <- [
          "alias Frameshift.Library, as: Library",
          "Frameshift.Library.list()",
          ":\"Elixir.Frameshift.Library\".list()"
        ] do
      assert [error] = inspect_source(context, "apps/platform/lib/sample.ex", source)
      assert error =~ "platform cannot depend on core"
    end
  end

  test "ignores module-like names in strings and comments", context do
    assert inspect_source(
             context,
             "apps/platform/lib/sample.ex",
             "# Frameshift.Library\n\"Frameshift.Library\""
           ) == []
  end

  test "rejects shared package imports of an application", context do
    assert [error] =
             inspect_source(
               context,
               "packages/decisions/lib/sample.ex",
               "alias FrameshiftPlatform.Repo"
             )

    assert error =~ "decisions cannot depend on platform"
  end

  test "rejects cross-application path dependencies", context do
    assert [error] =
             inspect_source(
               context,
               "apps/platform/mix.exs",
               "[{:frameshift_core, path: \"../core\"}]"
             )

    assert error =~ "platform cannot depend on core"
  end

  test "rejects an unregistered application", context do
    assert inspect_source(context, "apps/hidden/mix.exs", "[]") == [
             "apps/hidden/mix.exs: unowned Mix project"
           ]
  end

  test "rejects invalid syntax instead of skipping inspection", context do
    assert inspect_source(context, "apps/core/lib/broken.ex", "defmodule Broken do") == [
             "apps/core/lib/broken.ex: cannot inspect invalid Elixir syntax"
           ]
  end

  test "rejects cyclic and unknown dependencies", context do
    components =
      Enum.map(context.components, fn component ->
        if component["name"] == "decisions",
          do: %{component | "depends_on" => ["core", "missing"]},
          else: component
      end)

    errors = FrameshiftWorkspace.inspect_files(context.root, components, [])
    assert Enum.any?(errors, &String.contains?(&1, "dependency cycle"))
    assert Enum.any?(errors, &String.contains?(&1, "unknown dependency missing"))
  end

  defp inspect_source(context, file, source) do
    path = Path.join(context.root, file)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, source)
    FrameshiftWorkspace.inspect_files(context.root, context.components, [file])
  end
end
