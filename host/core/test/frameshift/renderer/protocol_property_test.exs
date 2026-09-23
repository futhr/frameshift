defmodule Frameshift.Renderer.ProtocolPropertyTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Frameshift.Renderer.Protocol

  property "every bounded RGB24 job has an exact self-describing wire length" do
    check all(
            width <- integer(1..32),
            height <- integer(1..32),
            crop_x <- integer(0..(width - 1)),
            crop_y <- integer(0..(height - 1)),
            crop_width <- integer(1..(width - crop_x)),
            crop_height <- integer(1..(height - crop_y)),
            target_width <- integer(1..32),
            target_height <- integer(1..32),
            rgba <- binary(length: width * height * 4)
          ) do
      job = %{
        source_width: width,
        source_height: height,
        crop_x: crop_x,
        crop_y: crop_y,
        crop_width: crop_width,
        crop_height: crop_height,
        target_width: target_width,
        target_height: target_height,
        background: {0, 0, 0},
        output_format: :rgb24,
        resize_filter: :bilinear,
        dither_mode: :none,
        palette: [],
        rgba: rgba
      }

      assert {:ok, [<<declared::unsigned-big-32>>, body]} = Protocol.encode_request(job)
      assert declared == byte_size(body)
      assert declared == 52 + byte_size(rgba)
      assert <<"FSR1", _rest::binary>> = body
    end
  end

  property "content digests are stable lowercase protocol identifiers" do
    check all(bytes <- binary(max_length: 16_384)) do
      digest = Frameshift.Digest.sha256(bytes)

      assert Frameshift.Digest.valid_sha256?(digest)
      assert Frameshift.Digest.hex!(digest) == String.replace_prefix(digest, "sha256:", "")
      assert digest == Frameshift.Digest.sha256(IO.iodata_to_binary([bytes]))
    end
  end
end
