defmodule Frameshift.RendererTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Frameshift.Renderer
  alias Frameshift.Renderer.Protocol

  @renderer_dir Path.expand("../../../../renderer", __DIR__)
  @renderer_path Path.join(@renderer_dir, "zig-out/bin/frameshift-raster")
  @hanging_worker Path.expand("../fixtures/hanging-worker.sh", __DIR__)
  @timeout_name Frameshift.RendererTest.TimeoutWorker

  setup_all do
    {output, status} =
      System.cmd("zig", ["build", "-Doptimize=ReleaseSafe"],
        cd: @renderer_dir,
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert File.regular?(@renderer_path)
    :ok
  end

  test "a real Zig worker returns the exact framed RGB artifact" do
    {:ok, renderer} = Renderer.start_link(path: @renderer_path, name: nil)

    assert {:ok, rendered} = Renderer.render(renderer, job())
    assert rendered == %{format: :rgb24, width: 2, height: 1, bytes: <<1, 2, 3, 4, 5, 6>>}

    GenServer.stop(renderer)
  end

  test "host validation rejects malformed work before it reaches the port" do
    assert Protocol.maximum_source_pixels() == 16_777_011

    assert {:error, :invalid_crop} =
             Protocol.encode_request(%{job() | crop_width: 3})

    assert {:error, :invalid_source_length} =
             Protocol.encode_request(%{job() | rgba: <<1, 2, 3>>})

    assert {:error, :invalid_profile} =
             Protocol.encode_request(%{job() | output_format: :rgb24, dither_mode: :ordered_2x2})

    assert {:error, :source_too_large} =
             Protocol.encode_request(%{
               job()
               | source_width: 4_096,
                 source_height: 4_096,
                 crop_width: 4_096,
                 crop_height: 4_096
             })
  end

  test "host validation failures do not terminate the owner" do
    {:ok, renderer} = Renderer.start_link(path: @renderer_path, name: nil)
    invalid_for_worker = %{job() | crop_width: 0}

    assert {:error, :invalid_dimensions} = Renderer.render(renderer, invalid_for_worker)
    assert {:error, :invalid_timeout} = Renderer.render(renderer, job(), deadline_ms: :never)
    assert Process.alive?(renderer)
    assert {:ok, _} = Renderer.render(renderer, job())

    GenServer.stop(renderer)
  end

  test "fragmented port responses are assembled once without changing bytes" do
    {:ok, renderer} = Renderer.start_link(path: @hanging_worker, name: nil)
    task = Task.async(fn -> Renderer.render(renderer, job(), deadline_ms: 1_000) end)
    assert eventually(fn -> :sys.get_state(renderer).pending != nil end)

    port = :sys.get_state(renderer).port
    payload = <<1, 2, 3, 4, 5, 6>>

    body =
      <<"FSO1", 0, 1, 0, 1, 2::unsigned-big-32, 1::unsigned-big-32, 6::unsigned-big-32,
        payload::binary>>

    frame = <<byte_size(body)::unsigned-big-32, body::binary>>
    <<first::binary-size(2), second::binary-size(5), rest::binary>> = frame

    send(renderer, {port, {:data, first}})
    send(renderer, {port, {:data, second}})
    send(renderer, {port, {:data, rest}})

    assert {:ok, %{format: :rgb24, width: 2, height: 1, bytes: ^payload}} =
             Task.await(task, 1_000)

    GenServer.stop(renderer)
  end

  test "a deadline kills the worker and its supervisor starts a clean owner" do
    capture_log(fn ->
      {:ok, supervisor} =
        Supervisor.start_link(
          [{Renderer, path: @hanging_worker, name: @timeout_name}],
          strategy: :one_for_one
        )

      first_owner = Process.whereis(@timeout_name)
      assert is_pid(first_owner)

      task = Task.async(fn -> Renderer.render(@timeout_name, job(), deadline_ms: 20) end)
      Process.sleep(5)
      assert {:error, :busy} = Renderer.render(@timeout_name, job(), deadline_ms: 20)
      assert {:error, :timeout} = Task.await(task, 1_000)

      assert eventually(fn ->
               owner = Process.whereis(@timeout_name)
               is_pid(owner) and owner != first_owner
             end)

      Supervisor.stop(supervisor)
    end)
  end

  test "worker error frames decode to stable reasons" do
    body = <<"FSO1", 0, 1, 4, 0, 0::unsigned-big-32, 0::unsigned-big-32, 0::unsigned-big-32>>
    framed = <<byte_size(body)::unsigned-big-32, body::binary>>

    assert {:ok, {:worker_error, :invalid_crop}, <<>>} = Protocol.take_response(framed)
  end

  test "diagnostic formatting redacts render bytes and buffered output" do
    status = %{
      state: %Renderer.State{port: self(), prefix: <<1, 2>>, chunks: [<<3, 4, 5>>]},
      message: {:render, job(), 100},
      log: [{:in, {:render, job(), 100}}]
    }

    redacted = Renderer.format_status(status)
    assert redacted.message == :redacted
    assert redacted.log == [:redacted]
    assert redacted.state.prefix == "<redacted>"
    assert redacted.state.chunks == [:redacted]
  end

  defp job do
    %{
      source_width: 2,
      source_height: 1,
      crop_x: 0,
      crop_y: 0,
      crop_width: 2,
      crop_height: 1,
      target_width: 2,
      target_height: 1,
      background: {0, 0, 0},
      output_format: :rgb24,
      resize_filter: :nearest,
      dither_mode: :none,
      palette: [],
      rgba: <<1, 2, 3, 255, 4, 5, 6, 255>>
    }
  end

  defp eventually(function, attempts \\ 50)
  defp eventually(_, 0), do: false

  defp eventually(function, attempts) do
    if function.() do
      true
    else
      Process.sleep(10)
      eventually(function, attempts - 1)
    end
  end
end
