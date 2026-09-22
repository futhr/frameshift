defmodule Frameshift.LocalAPI do
  @moduledoc """
  Product-facing local command boundary owned by the Elixir core.

  The Swift menu process is a client of this module through bounded local IPC;
  canonical library and setting state remain in the core. Import paths are
  copied immediately into content-addressed storage and are never persisted.
  """

  alias Frameshift.Library

  @maximum_import_bytes 128 * 1024 * 1024
  @maximum_dimension 32_768
  @maximum_pixels 268_435_456
  @instruction_key "generation.instruction"

  @type result :: {:ok, map()} | {:error, atom()}

  @spec snapshot(GenServer.server(), String.t()) :: map()
  def snapshot(library \\ Library, status_message \\ "Core connected • no paired frame") do
    %{
      "targets" => [],
      "selectedTargetID" => nil,
      "instruction" => setting(library, @instruction_key, ""),
      "items" => Enum.map(Library.search(library, "", limit: 100), &library_item/1),
      "generationAvailability" => "notConfigured",
      "statusMessage" => status_message
    }
  end

  @spec execute(GenServer.server(), map()) :: result()
  def execute(library \\ Library, command) do
    with :ok <- validate_command_shape(command) do
      do_execute(library, command)
    end
  end

  defp do_execute(library, %{"kind" => "updateInstruction", "instruction" => instruction})
       when is_binary(instruction) and byte_size(instruction) <= 4_096 do
    case Library.put_setting(library, @instruction_key, instruction) do
      :ok -> {:ok, snapshot(library, "Instruction saved")}
      {:error, _reason} -> {:error, :persistence_failed}
    end
  end

  defp do_execute(
         library,
         %{
           "kind" => "importFile",
           "importPath" => path,
           "importWidth" => width,
           "importHeight" => height,
           "importMediaType" => media_type
         } = command
       ) do
    with :ok <- validate_import_description(path, width, height, media_type, command),
         {:ok, bytes} <- read_import(path),
         ^media_type <- media_type(bytes),
         {:ok, _master} <-
           Library.import_master(library, bytes, %{
             title: import_title(path),
             source_kind: :import,
             width: width,
             height: height,
             media_type: media_type,
             orientation: Map.get(command, "importOrientation", 1),
             color_profile: Map.get(command, "importColorProfile"),
             provenance: %{
               "kind" => "local-import",
               "originalFilename" => Path.basename(path)
             }
           }) do
      {:ok, snapshot(library, "Image imported into the durable library")}
    else
      nil -> {:error, :unsupported_media_type}
      detected when is_binary(detected) -> {:error, :media_type_mismatch}
      {:error, reason} -> {:error, normalize_import_error(reason)}
    end
  end

  defp do_execute(library, %{
         "kind" => "setPinned",
         "itemID" => digest,
         "isPinned" => pinned
       })
       when is_binary(digest) and is_boolean(pinned) do
    result =
      with {:ok, _master} <- Library.get_master(library, digest) do
        if pinned, do: Library.pin(library, digest), else: Library.unpin(library, digest)
      end

    case result do
      :ok -> {:ok, snapshot(library, if(pinned, do: "Artwork pinned", else: "Artwork unpinned"))}
      :not_found -> {:error, :item_not_found}
      {:error, _reason} -> {:error, :item_not_found}
    end
  end

  defp do_execute(library, %{"kind" => "remove", "itemID" => digest})
       when is_binary(digest) do
    case Library.remove_master(library, digest) do
      :ok -> {:ok, snapshot(library, "Artwork moved to Recently Removed")}
      {:error, _reason} -> {:error, :item_not_found}
    end
  end

  defp do_execute(_library, %{"kind" => "selectTarget"}), do: {:error, :target_not_found}
  defp do_execute(_library, %{"kind" => "queue"}), do: {:error, :target_not_found}
  defp do_execute(_library, _command), do: {:error, :invalid_command}

  defp validate_command_shape(%{"kind" => kind} = command) when is_binary(kind) do
    id = Map.get(command, "id")
    allowed = allowed_command_keys(kind)

    cond do
      id != nil and (not is_binary(id) or byte_size(id) not in 1..64) ->
        {:error, :invalid_command}

      Enum.any?(Map.keys(command), &(&1 not in allowed)) ->
        {:error, :invalid_command}

      true ->
        :ok
    end
  end

  defp validate_command_shape(_command), do: {:error, :invalid_command}

  defp allowed_command_keys("updateInstruction"), do: ~w(id kind instruction)

  defp allowed_command_keys("importFile") do
    ~w(id kind importPath importWidth importHeight importMediaType importOrientation importColorProfile)
  end

  defp allowed_command_keys("setPinned"), do: ~w(id kind itemID isPinned)
  defp allowed_command_keys("remove"), do: ~w(id kind itemID)
  defp allowed_command_keys("selectTarget"), do: ~w(id kind targetID)
  defp allowed_command_keys("queue"), do: ~w(id kind targetID itemID)
  defp allowed_command_keys(_kind), do: ~w(id kind)

  defp setting(library, key, default) do
    case Library.get_setting(library, key) do
      {:ok, value} -> value
      :not_found -> default
      {:error, _reason} -> default
    end
  end

  defp library_item(master) do
    %{
      "id" => master["digest"],
      "title" => master["title"],
      "digest" => master["digest"],
      "isPinned" => master["pinned"],
      "queuedTargetID" => nil
    }
  end

  defp validate_import_description(path, width, height, media_type, command) do
    orientation = Map.get(command, "importOrientation", 1)
    color_profile = Map.get(command, "importColorProfile")

    with :ok <- validate_import_path(path),
         :ok <- validate_import_dimensions(width, height),
         :ok <- validate_import_media_type(media_type),
         :ok <- validate_import_orientation(orientation) do
      validate_import_color_profile(color_profile)
    end
  end

  defp validate_import_path(path)
       when is_binary(path) and byte_size(path) in 1..1_024,
       do: :ok

  defp validate_import_path(_path), do: {:error, :invalid_import}

  defp validate_import_dimensions(width, height)
       when is_integer(width) and is_integer(height) and width in 1..@maximum_dimension and
              height in 1..@maximum_dimension and width * height <= @maximum_pixels,
       do: :ok

  defp validate_import_dimensions(_width, _height), do: {:error, :invalid_dimensions}

  defp validate_import_media_type(media_type)
       when is_binary(media_type) and byte_size(media_type) <= 128,
       do: :ok

  defp validate_import_media_type(_media_type), do: {:error, :unsupported_media_type}

  defp validate_import_orientation(orientation) when orientation in 1..8, do: :ok
  defp validate_import_orientation(_orientation), do: {:error, :invalid_orientation}

  defp validate_import_color_profile(nil), do: :ok

  defp validate_import_color_profile(color_profile)
       when is_binary(color_profile) and byte_size(color_profile) <= 256,
       do: :ok

  defp validate_import_color_profile(_color_profile), do: {:error, :invalid_color_profile}

  defp read_import(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, file} ->
        try do
          with {:ok, info} <- :file.read_file_info(file),
               stat = File.Stat.from_record(info),
               :ok <- validate_import_stat(stat),
               bytes when is_binary(bytes) <- IO.binread(file, stat.size + 1),
               true <- byte_size(bytes) == stat.size do
            {:ok, bytes}
          else
            :eof -> {:error, :import_changed}
            false -> {:error, :import_changed}
            {:error, reason} -> {:error, reason}
          end
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_import_stat(%File.Stat{type: :regular, size: size})
       when size > 0 and size <= @maximum_import_bytes,
       do: :ok

  defp validate_import_stat(%File.Stat{type: :regular}), do: {:error, :import_too_large}
  defp validate_import_stat(%File.Stat{}), do: {:error, :import_not_regular}

  defp media_type(<<137, "PNG\r\n", 26, 10, _rest::binary>>), do: "image/png"
  defp media_type(<<255, 216, 255, _rest::binary>>), do: "image/jpeg"
  defp media_type(<<"GIF87a", _rest::binary>>), do: "image/gif"
  defp media_type(<<"GIF89a", _rest::binary>>), do: "image/gif"
  defp media_type(<<"II", 42, 0, _rest::binary>>), do: "image/tiff"
  defp media_type(<<"MM", 0, 42, _rest::binary>>), do: "image/tiff"
  defp media_type(<<"RIFF", _size::binary-size(4), "WEBP", _rest::binary>>), do: "image/webp"

  defp media_type(<<_size::unsigned-big-32, "ftyp", brand::binary-size(4), _rest::binary>>)
       when brand in ["heic", "heix", "hevc", "hevx"],
       do: "image/heic"

  defp media_type(<<_size::unsigned-big-32, "ftyp", brand::binary-size(4), _rest::binary>>)
       when brand in ["mif1", "msf1"],
       do: "image/heif"

  defp media_type(_bytes), do: nil

  defp import_title(path) do
    case path |> Path.basename() |> Path.rootname() |> String.trim() do
      "" -> "Imported image"
      title -> String.slice(title, 0, 256)
    end
  end

  defp normalize_import_error(reason)
       when reason in [
              :invalid_import,
              :invalid_dimensions,
              :invalid_orientation,
              :invalid_color_profile,
              :unsupported_media_type,
              :import_too_large,
              :import_not_regular,
              :import_changed
            ],
       do: reason

  defp normalize_import_error(_reason), do: :import_unreadable
end
