defmodule Frameshift.RenderProfileTest do
  use ExUnit.Case, async: true

  alias Frameshift.RenderProfile

  test "selects a structurally compatible profile and creates a centered crop" do
    master = %{"width" => 4, "height" => 4}
    capabilities = capabilities([rgb_profile("urn:frameshift:profile:photo-rgb24-v1", 2, 1)])

    assert {:ok, compilation} = RenderProfile.compile(master, capabilities)
    assert compilation.profile["id"] == "urn:frameshift:profile:photo-rgb24-v1"
    assert compilation.job.crop_x == 0
    assert compilation.job.crop_y == 1
    assert compilation.job.crop_width == 4
    assert compilation.job.crop_height == 2
    assert compilation.job.output_format == :rgb24
    assert compilation.attributes.media_type == "application/vnd.vendor.panel-rgb24"
  end

  test "selection depends on advertised structure rather than vendor naming" do
    unsupported =
      rgb_profile("urn:vendor:any-name", 2, 2)
      |> Map.put("compression", "zstd")

    compatible = rgb_profile("urn:another-vendor:opaque-profile", 2, 2)
    capabilities = capabilities([unsupported, compatible])

    assert {:ok, %{profile: ^compatible}} =
             RenderProfile.compile(%{"width" => 2, "height" => 2}, capabilities)

    assert {:error, :unsupported_profile} =
             RenderProfile.compile(
               %{"width" => 2, "height" => 2},
               capabilities,
               "urn:vendor:any-name"
             )
  end

  defp capabilities(profiles) do
    %{
      "color" => %{
        "kind" => "continuous",
        "colorSpaces" => ["srgb"],
        "transferFunction" => "srgb"
      },
      "storage" => %{"artifactProfiles" => profiles}
    }
  end

  defp rgb_profile(id, width, height) do
    %{
      "id" => id,
      "mediaType" => "application/vnd.vendor.panel-rgb24",
      "width" => width,
      "height" => height,
      "maximumAssetBytes" => width * height * 3,
      "rowAlignment" => 1,
      "byteOrder" => "not-applicable",
      "channelOrder" => "rgb",
      "bitDepth" => 8,
      "compression" => "none"
    }
  end
end
