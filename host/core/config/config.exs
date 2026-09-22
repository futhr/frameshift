import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :frameshift_core, start_library: true

import_config "#{config_env()}.exs"
