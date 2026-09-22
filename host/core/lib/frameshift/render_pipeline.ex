defmodule Frameshift.RenderPipeline do
  @moduledoc """
  Connects a durable, verified master package to the isolated renderer and
  immutable artifact cache.

  Image decoding remains an Apple-system boundary. The renderer receives only
  canonical RGBA8 bytes extracted from the content-addressed master; callers
  cannot inject replacement pixels for a registered digest.
  """

  alias Frameshift.Digest
  alias Frameshift.Library
  alias Frameshift.MasterPackage
  alias Frameshift.Renderer
  alias Frameshift.Renderer.Protocol, as: RendererProtocol

  @required_attributes ~w(profile_id renderer_revision media_type)a

  @spec render_stored_master(
          GenServer.server(),
          GenServer.server(),
          String.t(),
          map(),
          map()
        ) :: {:ok, map()} | {:error, term()}
  def render_stored_master(library, renderer, master_digest, job, attributes) do
    with :ok <- validate_attributes(attributes),
         :ok <- validate_master_digest(master_digest),
         {:ok, master} <- Library.get_master(library, master_digest),
         :ok <- validate_master(master, job),
         {:ok, %{"bytes" => package}} <-
           Library.read_object(library, master_digest, MasterPackage.maximum_package_bytes()),
         {:ok, decoded} <- MasterPackage.decode(package),
         :ok <- validate_decoded(decoded, job),
         render_job = Map.put(job, :rgba, decoded.rgba),
         {:ok, _request} <- RendererProtocol.encode_request(render_job),
         {:ok, recipe_hash} <- register_recipe(library, master_digest, render_job, attributes) do
      fetch_or_render(
        library,
        renderer,
        master_digest,
        recipe_hash,
        render_job,
        attributes
      )
    else
      :not_found -> {:error, :master_missing}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_attributes(attributes) when is_map(attributes) do
    missing = Enum.reject(@required_attributes, &Map.has_key?(attributes, &1))

    cond do
      missing != [] ->
        {:error, {:missing_fields, missing}}

      not Enum.all?(@required_attributes, &(is_binary(attributes[&1]) and attributes[&1] != "")) ->
        {:error, :invalid_attributes}

      true ->
        :ok
    end
  end

  defp validate_attributes(_attributes), do: {:error, :invalid_attributes}

  defp validate_master_digest(digest) do
    if Digest.valid_sha256?(digest), do: :ok, else: {:error, :invalid_master_digest}
  end

  defp validate_master(master, job) do
    cond do
      master["media_type"] != MasterPackage.media_type() ->
        {:error, :unsupported_source_representation}

      master["width"] != job.source_width or master["height"] != job.source_height ->
        {:error, :source_dimensions_mismatch}

      true ->
        :ok
    end
  end

  defp validate_decoded(decoded, job) do
    if decoded.width == job.source_width and decoded.height == job.source_height,
      do: :ok,
      else: {:error, :source_dimensions_mismatch}
  end

  defp register_recipe(library, master_digest, job, attributes) do
    recipe = %{
      "background" => Tuple.to_list(job.background),
      "crop" => %{
        "height" => job.crop_height,
        "width" => job.crop_width,
        "x" => job.crop_x,
        "y" => job.crop_y
      },
      "dither" => Atom.to_string(job.dither_mode),
      "outputFormat" => Atom.to_string(job.output_format),
      "palette" => Enum.map(job.palette, &Tuple.to_list/1),
      "profileId" => attributes.profile_id,
      "rendererRevision" => attributes.renderer_revision,
      "resizeFilter" => Atom.to_string(job.resize_filter),
      "sourceHeight" => job.source_height,
      "sourceRepresentation" => "rgba8",
      "sourceWidth" => job.source_width,
      "targetHeight" => job.target_height,
      "targetWidth" => job.target_width
    }

    Library.register_recipe(library, :composition, recipe, [master_digest])
  end

  defp fetch_or_render(library, renderer, master_digest, recipe_hash, job, attributes) do
    case Library.cached_artifact(
           library,
           recipe_hash,
           attributes.profile_id,
           attributes.renderer_revision
         ) do
      {:ok, artifact} ->
        {:ok, Map.put(artifact, :cache, :hit)}

      :not_found ->
        render_and_register(library, renderer, master_digest, recipe_hash, job, attributes)
    end
  end

  defp render_and_register(library, renderer, master_digest, recipe_hash, job, attributes) do
    with {:ok, rendered} <- Renderer.render(renderer, job),
         :ok <- validate_rendered(rendered, job) do
      Library.register_artifact(library, rendered.bytes, %{
        master_digest: master_digest,
        recipe_hash: recipe_hash,
        profile_id: attributes.profile_id,
        renderer_revision: attributes.renderer_revision,
        media_type: attributes.media_type
      })
    end
  end

  defp validate_rendered(rendered, job) do
    if rendered.format == job.output_format and
         rendered.width == job.target_width and rendered.height == job.target_height,
       do: :ok,
       else: {:error, :renderer_contract_mismatch}
  end
end
