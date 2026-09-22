defmodule Frameshift.Protocol.Schema do
  @moduledoc """
  Loads and validates Frame Protocol control documents against the canonical
  JSON Schema Draft 2020-12 files.

  Schemas are embedded at compile time so a release never resolves schema
  references over the network.
  """

  @schema_names ~w(
    capabilities
    common
    desired
    outbox-ack
    outbox-manifest
    playlist
    problem
    state
    thing-description
  )

  @schema_dir Path.expand("../../../../../protocol/schemas", __DIR__)

  for name <- @schema_names do
    @external_resource Path.join(@schema_dir, "#{name}.schema.json")
  end

  @schemas Map.new(@schema_names, fn name ->
             path = Path.join(@schema_dir, "#{name}.schema.json")
             {name, path |> File.read!() |> JSON.decode!()}
           end)

  @type schema_name :: String.t()

  @spec names() :: [schema_name()]
  def names, do: @schema_names

  @spec raw(schema_name()) :: {:ok, map()} | :error
  def raw(name), do: Map.fetch(@schemas, name)

  @spec validate(schema_name(), term()) :: :ok | {:error, term()}
  def validate(name, document) do
    with {:ok, root} <- compiled(name),
         {:ok, _validated} <- JSV.validate(document, root) do
      :ok
    end
  end

  @spec compiled(schema_name()) :: {:ok, JSV.Root.t()} | {:error, term()}
  def compiled(name) do
    cache_key = {__MODULE__, name}

    case :persistent_term.get(cache_key, :not_found) do
      :not_found -> compile_and_cache(cache_key, name)
      root -> {:ok, root}
    end
  end

  defp compile_and_cache(_cache_key, name) when name not in @schema_names,
    do: {:error, :unknown_schema}

  defp compile_and_cache(cache_key, name) do
    with {:ok, schema} <- raw(name),
         {:ok, root} <-
           JSV.build(schema,
             formats: true,
             resolver: {Frameshift.Protocol.SchemaResolver, @schemas}
           ) do
      :persistent_term.put(cache_key, root)
      {:ok, root}
    end
  end
end
