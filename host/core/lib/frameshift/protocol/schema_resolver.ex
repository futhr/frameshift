defmodule Frameshift.Protocol.SchemaResolver do
  @moduledoc false

  @behaviour JSV.Resolver

  @impl true
  def resolve(uri, schemas) when is_binary(uri) and is_map(schemas) do
    case Enum.find_value(schemas, fn {_name, schema} ->
           if schema["$id"] == uri, do: schema
         end) do
      nil -> {:error, {:unknown_schema, uri}}
      schema -> {:normal, schema}
    end
  end
end
