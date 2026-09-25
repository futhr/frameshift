defmodule Mix.Tasks.Frameshift.SeedCatalog do
  @moduledoc "Imports reviewed candidate data using an explicit local administrator attribution."

  use Mix.Task
  alias FrameshiftPlatform.Access.Actor
  alias FrameshiftPlatform.Catalog.SeedImport

  @shortdoc "Import public catalog seeds (--actor UUID --directory PATH)"
  @impl true
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: [actor: :string, directory: :string])
    id = opts[:actor]
    directory = opts[:directory]

    unless rest == [] and invalid == [] and is_binary(directory) and
             match?({:ok, _}, Ecto.UUID.cast(id)) do
      Mix.raise("Required: --actor UUID --directory PATH")
    end

    Mix.Task.run("app.config")
    endpoint = FrameshiftPlatformWeb.Endpoint
    config = Application.fetch_env!(:frameshift_platform, endpoint)
    Application.put_env(:frameshift_platform, endpoint, Keyword.put(config, :server, false))
    Mix.Task.run("app.start")

    case SeedImport.run(directory, %Actor{id: id, role: :catalog_editor}) do
      {:ok, counts} ->
        Mix.shell().info(
          "Catalog import complete: #{counts.sources} sources, #{counts.profiles} profiles"
        )

      {:error, error} ->
        Mix.raise("Catalog import refused: #{inspect(error)}")
    end
  end
end
