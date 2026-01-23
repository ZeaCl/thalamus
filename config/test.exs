import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :thalamus, Thalamus.Repo,
  username: System.get_env("DB_USER") || "dev",
  password: System.get_env("DB_PASSWORD") || "",
  hostname: System.get_env("DB_HOST") || "localhost",
  database: "thalamus_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :thalamus, ThalamusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LdKro4VE1x55xLQ08UQ9Ef8JEhpCejwSDvpmSS1TOBvjx4UHKF+2TikmFf1UeS1D",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable rate limiting during tests
# Tests run rapidly and would hit the production limits (20 req/min for authorization)
# This allows us to test actual functionality without rate limit interference
config :thalamus, :rate_limiting_enabled, false

# Configure Hammer with very high limits for test environment
# This is a fallback in case rate limiting is enabled
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000, cleanup_interval_ms: 60_000]}

# Enable all feature flags in test environment
config :thalamus, :feature_flags, %{
  agent_tokens: true
}

# Configure Oban for test environment (disable all queues and plugins)
config :thalamus, Oban,
  testing: :manual,
  queues: false,
  plugins: false
