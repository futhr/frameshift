defmodule Frameshift.LocalAPITest do
  use ExUnit.Case, async: true

  alias Frameshift.Library
  alias Frameshift.LocalAPI

  @png <<137, "PNG\r\n", 26, 10, 0, 0, 0, 13, "IHDR", 0, 0, 0, 2, 0, 0, 0, 1, 8, 6, 0, 0, 0>>

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-local-api-test-#{System.unique_integer([:positive, :monotonic])}"
      )

    data_dir = Path.join(root, "library")
    import_path = Path.join(root, "quiet-study.png")
    File.mkdir_p!(root)
    File.write!(import_path, @png, [:binary])
    {:ok, library} = Library.start_link(data_dir: data_dir, name: nil)

    on_exit(fn ->
      if Process.alive?(library), do: GenServer.stop(library)
      File.rm_rf!(root)
    end)

    %{data_dir: data_dir, import_path: import_path, library: library}
  end

  test "commands mutate durable core state rather than a shell-owned copy", context do
    assert %{
             "targets" => [],
             "selectedTargetID" => nil,
             "items" => [],
             "generationAvailability" => "notConfigured"
           } = LocalAPI.snapshot(context.library)

    assert {:ok, snapshot} =
             LocalAPI.execute(context.library, %{
               "kind" => "updateInstruction",
               "instruction" => "A quiet geometric still"
             })

    assert snapshot["instruction"] == "A quiet geometric still"

    assert {:ok, imported} =
             LocalAPI.execute(context.library, import_command(context.import_path))

    assert [%{"title" => "quiet-study", "isPinned" => false} = item] = imported["items"]

    assert {:ok, pinned} =
             LocalAPI.execute(context.library, %{
               "kind" => "setPinned",
               "itemID" => item["id"],
               "isPinned" => true
             })

    assert [%{"isPinned" => true}] = pinned["items"]

    GenServer.stop(context.library)
    {:ok, restarted} = Library.start_link(data_dir: context.data_dir, name: nil)

    assert %{"instruction" => "A quiet geometric still", "items" => [persisted]} =
             LocalAPI.snapshot(restarted)

    assert persisted["digest"] == item["digest"]
    assert persisted["isPinned"]

    GenServer.stop(restarted)
  end

  test "import validates Apple-decoded metadata against the actual file type", context do
    assert {:error, :media_type_mismatch} =
             context.import_path
             |> import_command()
             |> Map.put("importMediaType", "image/jpeg")
             |> then(&LocalAPI.execute(context.library, &1))

    assert {:error, :invalid_dimensions} =
             context.import_path
             |> import_command()
             |> Map.put("importWidth", 0)
             |> then(&LocalAPI.execute(context.library, &1))

    assert {:error, :invalid_command} =
             context.import_path
             |> import_command()
             |> Map.put("credential", "must-not-cross-this-boundary")
             |> then(&LocalAPI.execute(context.library, &1))
  end

  test "remove is recoverable library state and unavailable target commands fail explicitly",
       context do
    assert {:ok, imported} =
             LocalAPI.execute(context.library, import_command(context.import_path))

    [item] = imported["items"]

    assert {:ok, %{"items" => []}} =
             LocalAPI.execute(context.library, %{"kind" => "remove", "itemID" => item["id"]})

    assert {:ok, _removed_master} = Library.get_master(context.library, item["digest"])
    assert {:error, :target_not_found} = LocalAPI.execute(context.library, %{"kind" => "queue"})

    missing = "sha256:" <> String.duplicate("0", 64)

    assert {:error, :item_not_found} =
             LocalAPI.execute(context.library, %{
               "kind" => "setPinned",
               "itemID" => missing,
               "isPinned" => false
             })
  end

  defp import_command(path) do
    %{
      "kind" => "importFile",
      "importPath" => path,
      "importWidth" => 2,
      "importHeight" => 1,
      "importMediaType" => "image/png",
      "importOrientation" => 1,
      "importColorProfile" => "sRGB"
    }
  end
end
