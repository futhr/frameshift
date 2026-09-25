import Config

config :ash, default_string_length_count: :codepoints
config :frameshift_platform, ecto_repos: [FrameshiftPlatform.Repo]
config :frameshift_platform, :ash_domains, [FrameshiftPlatform.Access, FrameshiftPlatform.Catalog]

config :frameshift_platform, FrameshiftPlatformWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: FrameshiftPlatformWeb.ErrorJSON], layout: false],
  pubsub_server: FrameshiftPlatform.PubSub

config :phoenix, :json_library, Jason

config :phoenix_assets,
  otp_app: :frameshift_platform,
  endpoint: FrameshiftPlatformWeb.Endpoint,
  router: FrameshiftPlatformWeb.Router,
  package_manager: :npm

config :phoenix_assets, :stack,
  locales: ["en"],
  default_locale: "en",
  types: FrameshiftPlatform.Assets.Types

config :phoenix_assets, :dev, enabled: false, storybook: [enabled: false]

import_config "#{config_env()}.exs"
