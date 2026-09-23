defmodule Frameshift.RenderProfile do
  @moduledoc """
  Compiles an advertised artifact-profile instance into a deterministic raster
  job without consulting vendor or model names.

  The current compiler accepts exact uncompressed, tightly packed RGB24
  profiles in sRGB. Other valid universal profiles remain discoverable but fail
  explicitly until their packer/color implementation is present.
  """

  @renderer_revision "frameshift-raster-v0.1"
  @maximum_pixels 16_777_216

  @type compilation :: %{
          job: map(),
          attributes: map(),
          profile: map()
        }

  @doc "Selects a compatible advertised profile and compiles a centered raster job."
  @spec compile(map(), map(), String.t() | nil) :: {:ok, compilation()} | {:error, atom()}
  def compile(master, capabilities, requested_profile_id \\ nil)

  def compile(master, capabilities, requested_profile_id)
      when is_map(master) and is_map(capabilities) do
    with {:ok, profiles} <- artifact_profiles(capabilities),
         {:ok, profile} <- select_profile(profiles, capabilities, requested_profile_id),
         :ok <- validate_source(master),
         :ok <- validate_target(profile),
         {crop_x, crop_y, crop_width, crop_height} <- center_crop(master, profile) do
      {:ok,
       %{
         job: %{
           source_width: master["width"],
           source_height: master["height"],
           crop_x: crop_x,
           crop_y: crop_y,
           crop_width: crop_width,
           crop_height: crop_height,
           target_width: profile["width"],
           target_height: profile["height"],
           background: {255, 255, 255},
           output_format: :rgb24,
           resize_filter: :bilinear,
           dither_mode: :none,
           palette: []
         },
         attributes: %{
           profile_id: profile["id"],
           renderer_revision: @renderer_revision,
           media_type: profile["mediaType"]
         },
         profile: profile
       }}
    end
  end

  def compile(_, _, _),
    do: {:error, :invalid_render_profile}

  defp artifact_profiles(%{"storage" => %{"artifactProfiles" => profiles}})
       when is_list(profiles) and profiles != [],
       do: {:ok, profiles}

  defp artifact_profiles(_), do: {:error, :artifact_profiles_missing}

  defp select_profile(profiles, capabilities, nil) do
    profiles
    |> Enum.sort_by(& &1["id"])
    |> Enum.find(&compatible?(&1, capabilities))
    |> selected_profile()
  end

  defp select_profile(profiles, capabilities, requested_profile_id)
       when is_binary(requested_profile_id) do
    profiles
    |> Enum.find(&(&1["id"] == requested_profile_id))
    |> case do
      nil ->
        {:error, :unsupported_profile}

      profile ->
        if compatible?(profile, capabilities),
          do: {:ok, profile},
          else: {:error, :unsupported_profile}
    end
  end

  defp select_profile(_, _, _),
    do: {:error, :unsupported_profile}

  defp selected_profile(nil), do: {:error, :unsupported_profile}
  defp selected_profile(profile), do: {:ok, profile}

  defp compatible?(profile, capabilities) do
    color = capabilities["color"]
    pixels = profile["width"] * profile["height"]
    expected_bytes = pixels * 3

    [
      profile["channelOrder"] == "rgb",
      profile["bitDepth"] == 8,
      profile["compression"] == "none",
      profile["rowAlignment"] == 1,
      profile["byteOrder"] == "not-applicable",
      color["kind"] == "continuous",
      "srgb" in color["colorSpaces"],
      color["transferFunction"] == "srgb",
      pixels <= @maximum_pixels,
      expected_bytes <= profile["maximumAssetBytes"]
    ]
    |> Enum.all?()
  rescue
    _ -> false
  end

  defp validate_source(%{"width" => width, "height" => height})
       when is_integer(width) and is_integer(height) and width > 0 and height > 0 and
              width * height <= @maximum_pixels,
       do: :ok

  defp validate_source(_), do: {:error, :invalid_source_dimensions}

  defp validate_target(%{"width" => width, "height" => height})
       when is_integer(width) and is_integer(height) and width > 0 and height > 0 and
              width * height <= @maximum_pixels,
       do: :ok

  defp validate_target(_), do: {:error, :invalid_target_dimensions}

  defp center_crop(master, profile) do
    source_width = master["width"]
    source_height = master["height"]
    target_width = profile["width"]
    target_height = profile["height"]

    if source_width * target_height > source_height * target_width do
      crop_width = max(1, div(source_height * target_width, target_height))
      {div(source_width - crop_width, 2), 0, crop_width, source_height}
    else
      crop_height = max(1, div(source_width * target_height, target_width))
      {0, div(source_height - crop_height, 2), source_width, crop_height}
    end
  end
end
