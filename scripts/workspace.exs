defmodule FrameshiftWorkspace do
  @moduledoc """
  Checks workspace ownership, declared dependencies and static Elixir references.

  Reads syntax without evaluating project files. This is an architecture check,
  not a security sandbox for dynamic code or cross-process communication.
  """

  @spec check(String.t()) :: [String.t()]
  def check(root) do
    components =
      root
      |> Path.join("workspace.json")
      |> File.read!()
      |> :json.decode()
      |> Map.fetch!("components")

    {files, 0} =
      System.cmd("git", ["ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cd: root
      )

    inspect_files(root, components, String.split(files, <<0>>, trim: true))
  end

  @spec inspect_files(String.t(), [map()], [String.t()]) :: [String.t()]
  def inspect_files(root, components, files) do
    configuration_errors(root, components) ++
      Enum.flat_map(files, &file_errors(root, components, &1))
  end

  defp configuration_errors(root, components) do
    names = Enum.map(components, & &1["name"])
    roots = Enum.map(components, & &1["root"])
    duplicates = duplicate_errors(names, "component") ++ duplicate_errors(roots, "root")
    duplicates ++ Enum.flat_map(components, &component_errors(root, components, names, &1))
  end

  defp duplicate_errors(values, kind) do
    values
    |> Enum.frequencies()
    |> Enum.filter(fn {_, count} -> count > 1 end)
    |> Enum.map(fn {value, _} -> "duplicate #{kind}: #{value}" end)
  end

  defp component_errors(root, components, names, component) do
    unknown = component["depends_on"] -- names
    errors = Enum.map(unknown, &"#{component["name"]}: unknown dependency #{&1}")
    errors = errors ++ cycle_errors(component["name"], component["name"], components, [])
    location = component["root"]

    cond do
      Path.type(location) != :relative or Path.expand(location, root) == root or
          not String.starts_with?(Path.expand(location, root), root <> "/") ->
        ["#{component["name"]}: root must stay inside workspace" | errors]

      component["planned"] != true and not File.dir?(Path.join(root, location)) ->
        ["#{component["name"]}: missing root #{location}" | errors]

      true ->
        errors
    end
  end

  defp cycle_errors(start, current, components, seen) do
    cond do
      current in seen ->
        ["dependency cycle from #{start}: #{Enum.join(Enum.reverse([current | seen]), " -> ")}"]

      component = Enum.find(components, &(&1["name"] == current)) ->
        Enum.flat_map(
          component["depends_on"],
          &cycle_errors(start, &1, components, [current | seen])
        )

      true ->
        []
    end
  end

  defp file_errors(root, components, file) do
    owner = owner_for_path(components, file)

    cond do
      Path.basename(file) == "mix.exs" and is_nil(owner) -> ["#{file}: unowned Mix project"]
      is_nil(owner) or Path.extname(file) not in [".ex", ".exs"] -> []
      true -> inspect_elixir(root, components, owner, file)
    end
  end

  defp inspect_elixir(root, components, owner, file) do
    case Code.string_to_quoted(File.read!(Path.join(root, file)), columns: true) do
      {:ok, ast} ->
        {_, errors} = Macro.prewalk(ast, [], &inspect_node(&1, &2, components, owner, file, root))
        Enum.uniq(Enum.reverse(errors))

      {:error, _} ->
        ["#{file}: cannot inspect invalid Elixir syntax"]
    end
  end

  defp inspect_node({:__aliases__, meta, names} = node, errors, components, owner, file, _) do
    name =
      names
      |> Enum.take_while(&is_atom/1)
      |> Enum.map_join(".", &Atom.to_string/1)
      |> String.trim_leading("Elixir.")

    {node, reference_errors(components, owner, name, "#{file}:#{meta[:line]}") ++ errors}
  end

  defp inspect_node({:path, path} = node, errors, components, owner, file, root)
       when is_binary(path) do
    target = path |> Path.expand(Path.dirname(Path.join(root, file))) |> Path.relative_to(root)
    target_owner = owner_for_path(components, target)
    error = dependency_error(owner, target_owner, "#{file}: path #{path}")
    {node, error ++ errors}
  end

  defp inspect_node(node, errors, components, owner, file, _) when is_atom(node) do
    name = Atom.to_string(node)

    if String.starts_with?(name, "Elixir.") or name == String.downcase(name) do
      {node,
       reference_errors(components, owner, String.trim_leading(name, "Elixir."), file) ++ errors}
    else
      {node, errors}
    end
  end

  defp inspect_node(node, errors, _, _, _, _), do: {node, errors}

  defp reference_errors(components, owner, name, location) do
    target =
      Enum.find(components, fn component ->
        Enum.any?(component["modules"], &module_matches?(name, &1))
      end)

    dependency_error(owner, target, "#{location}: #{name}")
  end

  defp module_matches?(name, prefix),
    do: name == prefix or String.starts_with?(name, prefix <> ".")

  defp dependency_error(_, nil, _), do: []

  defp dependency_error(owner, target, location) do
    if target["name"] == owner["name"] or target["name"] in owner["depends_on"] do
      []
    else
      ["#{location}: #{owner["name"]} cannot depend on #{target["name"]}"]
    end
  end

  defp owner_for_path(components, file) do
    Enum.find(components, &(file == &1["root"] or String.starts_with?(file, &1["root"] <> "/")))
  end
end
