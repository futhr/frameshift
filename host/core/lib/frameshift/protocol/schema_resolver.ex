defmodule Frameshift.Protocol.SchemaResolver do
  @moduledoc """
  Resolves protocol schema references from the embedded schema set only.

  Control or Thing Description validation never fetches a remote schema, so
  an untrusted document cannot trigger network I/O or redefine validation.
  """

  @behaviour JSV.Resolver

  @impl true
  def resolve(uri, schemas) when is_binary(uri) and is_map(schemas) do
    case Enum.find(Map.values(schemas), &(&1["$id"] == uri)) do
      nil -> {:error, {:unknown_schema, uri}}
      schema -> {:normal, schema}
    end
  end
end
