import Config

config :frameshift_platform, :metrics_token, System.get_env("FRAMESHIFT_METRICS_TOKEN")

if config_env() == :prod do
  config :frameshift_platform, FrameshiftPlatform.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  host = System.fetch_env!("PHX_HOST")

  config :frameshift_platform, FrameshiftPlatformWeb.Endpoint,
    server: true,
    url: [scheme: "https", host: host, port: 443],
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4080"))],
    check_origin: ["https://#{host}"],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
end
