import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :frameshift_core,
  start_library: true,
  start_renderer: true,
  start_local_ipc: true,
  renderer_path:
    System.get_env("FRAMESHIFT_RENDERER_PATH") ||
      Path.expand("../../../renderer/zig-out/bin/frameshift-raster", __DIR__)

import_config "#{config_env()}.exs"
