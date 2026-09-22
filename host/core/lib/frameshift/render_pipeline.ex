defmodule Frameshift.RenderPipeline do
  @moduledoc """
  Connects a durable, verified canonical RGBA8 master to the isolated renderer
  and immutable artifact cache.

  Image decoding remains an Apple-system boundary. This generic-profile entry
  point reads RGBA8 bytes back from the content-addressed store; callers do not
  inject replacement pixels for a registered digest.
  """

  alias Frameshift.Digest
  alias Frameshift.Library
  alias Frameshift.Renderer
  alias Frameshift.Renderer.Protocol, as: RendererProtocol

  @required_attributes ~w(profile_id renderer_revision media_type)a

  @spec render_stored_rgba_master(
          GenServer.server(),
          GenServer.server(),
          String.t(),
          map(),
          map()
        ) :: {:ok, map()} | {:error, term()}
  def render_stored_rgba_master(library, renderer, master_digest, job, attributes) do
    with {:ok, expected_bytes} <- expected_source_bytes(job),
         {:ok, %{"bytes" => rgba}} <- Library.read_object(library, master_digest, expected_bytes),
         true <- byte_size(rgba) == expected_bytes do
      render_rgba_master(library, renderer, master_digest, Map.put(job, :rgba, rgba), attributes)
    else
      :not_found -> {:error, :master_missing}
      false -> {:error, :source_dimensions_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec render_rgba_master(
          GenServer.server(),
          GenServer.server(),
          String.t(),
          map(),
          map()
        ) :: {:ok, map()} | {:error, term()}
  def render_rgba_master(library, renderer, master_digest, job, attributes) do
    with :ok <- validate_attributes(attributes),
         :ok <- validate_master_digest(master_digest),
         {:ok, _request} <- RendererProtocol.encode_request(job),
         :ok <- validate_source_digest(master_digest, job.rgba),
         {:ok, master} <- Library.get_master(library, master_digest),
         :ok <- validate_master(master, job),
         {:ok, recipe_hash} <- register_recipe(library, master_digest, job, attributes) do
      fetch_or_render(library, renderer, master_digest, recipe_hash, job, attributes)
    else
      :not_found -> {:error, :master_missing}
      {:error, reason} -> {:error, reason}
    end
  end

  defp expected_source_bytes(%{source_width: width, source_height: height})
       when is_integer(width) and is_integer(height) and width > 0 and height > 0 and
              width <= 32_768 and height <= 32_768 and width * height <= 16_777_216,
       do: {:ok, width * height * 4}

  defp expected_source_bytes(_job), do: {:error, :invalid_dimensions}

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

  defp validate_source_digest(master_digest, rgba) do
    if Digest.sha256(rgba) == master_digest, do: :ok, else: {:error, :source_mismatch}
  end

  defp validate_master(master, job) do
    cond do
      master["media_type"] != "application/vnd.frameshift.experimental.rgba8" ->
        {:error, :unsupported_source_representation}

      master["width"] != job.source_width or master["height"] != job.source_height ->
        {:error, :source_dimensions_mismatch}

      true ->
        :ok
    end
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
