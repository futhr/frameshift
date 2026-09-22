defmodule Frameshift.Renderer.Protocol do
  @moduledoc false

  @maximum_frame_bytes 64 * 1024 * 1024
  @maximum_dimension 32_768
  @maximum_pixels 16_777_216

  @output_formats %{rgb24: 1, indexed8: 2}
  @resize_filters %{nearest: 1, bilinear: 2}
  @dither_modes %{none: 0, ordered_2x2: 1, floyd_steinberg: 2}
  @worker_errors %{
    1 => :malformed,
    2 => :unsupported_version,
    3 => :bounds_exceeded,
    4 => :invalid_crop,
    5 => :invalid_profile,
    6 => :allocation_failed
  }

  @required_job_fields ~w(
    source_width
    source_height
    crop_x
    crop_y
    crop_width
    crop_height
    target_width
    target_height
    background
    output_format
    resize_filter
    dither_mode
    palette
    rgba
  )a

  @spec maximum_frame_bytes() :: pos_integer()
  def maximum_frame_bytes, do: @maximum_frame_bytes

  @spec encode_request(map()) :: {:ok, iodata()} | {:error, term()}
  def encode_request(job) when is_map(job) do
    with :ok <- required_fields(job),
         :ok <- validate_dimensions(job),
         :ok <- validate_crop(job),
         :ok <- validate_source(job),
         {:ok, output} <- fetch_code(@output_formats, job.output_format),
         {:ok, resize} <- fetch_code(@resize_filters, job.resize_filter),
         {:ok, dither} <- fetch_code(@dither_modes, job.dither_mode),
         {:ok, background} <- encode_color(job.background),
         {:ok, palette} <- encode_palette(job.palette),
         :ok <- validate_profile(job) do
      body =
        <<
          "FSR1",
          0,
          1,
          1,
          output,
          resize,
          dither,
          0::unsigned-big-16,
          job.source_width::unsigned-big-32,
          job.source_height::unsigned-big-32,
          job.crop_x::unsigned-big-32,
          job.crop_y::unsigned-big-32,
          job.crop_width::unsigned-big-32,
          job.crop_height::unsigned-big-32,
          job.target_width::unsigned-big-32,
          job.target_height::unsigned-big-32,
          background::binary,
          0,
          length(job.palette)::unsigned-big-16,
          0::unsigned-big-16,
          palette::binary,
          job.rgba::binary
        >>

      if byte_size(body) <= @maximum_frame_bytes,
        do: {:ok, [<<byte_size(body)::unsigned-big-32>>, body]},
        else: {:error, :request_too_large}
    end
  end

  def encode_request(_job), do: {:error, :invalid_job}

  @spec take_response(binary()) ::
          {:more, binary()}
          | {:ok, {:ok, map()} | {:worker_error, atom()}, binary()}
          | {:error, term()}
  def take_response(buffer) when byte_size(buffer) < 4, do: {:more, buffer}

  def take_response(<<length::unsigned-big-32, rest::binary>> = buffer) do
    cond do
      length > @maximum_frame_bytes ->
        {:error, :response_too_large}

      byte_size(rest) < length ->
        {:more, buffer}

      true ->
        <<body::binary-size(^length), remainder::binary>> = rest

        case decode_response(body) do
          {:ok, result} -> {:ok, result, remainder}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @spec decode_response(binary()) ::
          {:ok, {:ok, map()} | {:worker_error, atom()}} | {:error, term()}
  def decode_response(<<
        "FSO1",
        0,
        1,
        status,
        output,
        width::unsigned-big-32,
        height::unsigned-big-32,
        payload_length::unsigned-big-32,
        payload::binary
      >>) do
    with true <- byte_size(payload) == payload_length,
         {:ok, result} <- decode_status(status, output, width, height, payload) do
      {:ok, result}
    else
      false -> {:error, :invalid_response_length}
      {:error, reason} -> {:error, reason}
    end
  end

  def decode_response(_body), do: {:error, :invalid_response}

  defp decode_status(0, output, width, height, payload) do
    with {:ok, format, bytes_per_pixel} <- decode_output(output),
         :ok <- validate_response_dimensions(width, height),
         true <- byte_size(payload) == width * height * bytes_per_pixel do
      {:ok, {:ok, %{format: format, width: width, height: height, bytes: payload}}}
    else
      false -> {:error, :invalid_response_length}
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_status(status, 0, 0, 0, <<>>) do
    case Map.fetch(@worker_errors, status) do
      {:ok, reason} -> {:ok, {:worker_error, reason}}
      :error -> {:error, :unknown_worker_status}
    end
  end

  defp decode_status(_status, _output, _width, _height, _payload),
    do: {:error, :invalid_error_response}

  defp decode_output(1), do: {:ok, :rgb24, 3}
  defp decode_output(2), do: {:ok, :indexed8, 1}
  defp decode_output(_output), do: {:error, :invalid_output_format}

  defp required_fields(job) do
    case Enum.reject(@required_job_fields, &Map.has_key?(job, &1)) do
      [] -> :ok
      missing -> {:error, {:missing_fields, missing}}
    end
  end

  defp validate_dimensions(job) do
    dimensions = [
      job.source_width,
      job.source_height,
      job.crop_width,
      job.crop_height,
      job.target_width,
      job.target_height
    ]

    cond do
      not Enum.all?(dimensions, &(is_integer(&1) and &1 > 0 and &1 <= @maximum_dimension)) ->
        {:error, :invalid_dimensions}

      job.source_width * job.source_height > @maximum_pixels ->
        {:error, :source_too_large}

      job.target_width * job.target_height > @maximum_pixels ->
        {:error, :target_too_large}

      true ->
        :ok
    end
  end

  defp validate_crop(job) do
    valid_origin =
      is_integer(job.crop_x) and job.crop_x >= 0 and
        is_integer(job.crop_y) and job.crop_y >= 0

    if valid_origin and
         job.crop_x + job.crop_width <= job.source_width and
         job.crop_y + job.crop_height <= job.source_height,
       do: :ok,
       else: {:error, :invalid_crop}
  end

  defp validate_source(job) do
    if is_binary(job.rgba) and
         byte_size(job.rgba) == job.source_width * job.source_height * 4,
       do: :ok,
       else: {:error, :invalid_source_length}
  end

  defp validate_profile(%{output_format: :rgb24, palette: [], dither_mode: :none}), do: :ok

  defp validate_profile(%{output_format: :indexed8, palette: palette})
       when length(palette) in 1..256,
       do: :ok

  defp validate_profile(_job), do: {:error, :invalid_profile}

  defp fetch_code(codes, value) do
    case Map.fetch(codes, value) do
      {:ok, code} -> {:ok, code}
      :error -> {:error, :invalid_profile}
    end
  end

  defp encode_palette(palette) when is_list(palette) and length(palette) <= 256 do
    Enum.reduce_while(palette, {:ok, <<>>}, fn color, {:ok, encoded} ->
      case encode_color(color) do
        {:ok, bytes} -> {:cont, {:ok, <<encoded::binary, bytes::binary>>}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp encode_palette(_palette), do: {:error, :invalid_palette}

  defp encode_color({red, green, blue}) do
    if Enum.all?([red, green, blue], &(is_integer(&1) and &1 in 0..255)),
      do: {:ok, <<red, green, blue>>},
      else: {:error, :invalid_color}
  end

  defp encode_color(_color), do: {:error, :invalid_color}

  defp validate_response_dimensions(width, height) do
    if width > 0 and height > 0 and
         width <= @maximum_dimension and height <= @maximum_dimension and
         width * height <= @maximum_pixels,
       do: :ok,
       else: {:error, :invalid_response_dimensions}
  end
end
