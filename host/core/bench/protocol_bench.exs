alias Frameshift.Protocol.JSON, as: ProtocolJSON
alias Frameshift.Renderer.Protocol, as: RendererProtocol

File.mkdir_p!("bench/output")

desired = %{
  "assetDigest" => Frameshift.Digest.sha256(:binary.copy(<<42>>, 4_096)),
  "artifactProfile" => "urn:frameshift:profile:benchmark-rgb24-v1",
  "requestId" => "benchmark-request"
}

{:ok, desired_json} = ProtocolJSON.encode(desired)

Benchee.run(
  %{
    "decode and validate desired state" => fn ->
      {:ok, ^desired} = ProtocolJSON.decode_control(desired_json, "desired")
    end,
    "canonical encode desired state" => fn ->
      {:ok, ^desired_json} = ProtocolJSON.encode(desired)
    end
  },
  warmup: 1,
  time: 3,
  memory_time: 1,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown,
     file: "bench/output/protocol-json.md",
     title: "# Frame Protocol JSON admission",
     description: """
     Canonical encoding and bounded, schema-validated decoding of the desired-state
     document used by direct frame synchronization.
     """}
  ]
)

width = 256
height = 256

render_job = %{
  source_width: width,
  source_height: height,
  crop_x: 0,
  crop_y: 0,
  crop_width: width,
  crop_height: height,
  target_width: width,
  target_height: height,
  background: {255, 255, 255},
  output_format: :rgb24,
  resize_filter: :bilinear,
  dither_mode: :none,
  palette: [],
  rgba: :binary.copy(<<32, 64, 128, 255>>, width * height)
}

Benchee.run(
  %{
    "validate and encode a 256x256 render request" => fn ->
      {:ok, _} = RendererProtocol.encode_request(render_job)
    end
  },
  warmup: 1,
  time: 3,
  memory_time: 1,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown,
     file: "bench/output/renderer-wire.md",
     title: "# Renderer request admission",
     description: """
     Full validation and binary framing of a 256 × 256 canonical RGBA master for
     the supervised Zig renderer.
     """}
  ]
)
