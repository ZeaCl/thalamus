# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :thalamus,
  ecto_repos: [Thalamus.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :thalamus, ThalamusWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ThalamusWeb.ErrorHTML, json: ThalamusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Thalamus.PubSub,
  live_view: [signing_salt: "hKK6HjNn"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  thalamus: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  thalamus: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure email service
config :thalamus, Thalamus.Infrastructure.Adapters.EmailServiceImpl,
  mode: :development,
  from_email: "noreply@localhost",
  from_name: "ZEA Thalamus (Dev)",
  base_url: "http://localhost:4000"

# Security tokens configuration
config :thalamus,
  verification_token_secret: "change_me_in_production_verification",
  password_reset_secret: "change_me_in_production_password_reset",
  session_secret: "change_me_in_production_session"

# CORS configuration
config :thalamus, ThalamusWeb.Plugs.CORS,
  origins: ["http://localhost:3000", "http://localhost:4000"],
  allow_credentials: true,
  max_age: 86400,
  expose_headers: ["x-ratelimit-limit", "x-ratelimit-remaining", "x-ratelimit-reset"]

# Security headers configuration
config :thalamus, ThalamusWeb.Plugs.SecurityHeaders,
  frame_options: "DENY",
  hsts_max_age: 31_536_000

# Hammer rate limiting configuration
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 2, cleanup_interval_ms: 60_000 * 10]}

# Redis cache configuration
config :thalamus,
  redis_url: System.get_env("REDIS_URL", "redis://localhost:6379/0"),
  # Using real Redis for production-grade caching
  redis_adapter: :redix,
  base_url: System.get_env("BASE_URL", "http://localhost:4000")

# Swoosh email configuration
config :thalamus, Thalamus.Mailer,
  # Default to Local adapter, override in env configs
  adapter: Swoosh.Adapters.Local

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
