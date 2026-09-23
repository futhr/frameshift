import Config

if config_env() == :prod do
  renderer_path =
    System.get_env("FRAMESHIFT_RENDERER_PATH") ||
      raise "FRAMESHIFT_RENDERER_PATH is required in production"

  config :frameshift_core, renderer_path: Path.expand(renderer_path)

  config :logger, :console,
    format: {Frameshift.Diagnostics.LogFormatter, :format},
    metadata: [:frameshift_event, :frameshift_outcome, :request_id, :command_id, :duration_ms]
end
