import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/thalamus start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :thalamus, ThalamusWeb.Endpoint, server: true
end

# CORS configuration — read from environment variable
if cors_origins = System.get_env("CORS_ORIGINS") do
  origins =
    cors_origins
    |> String.split(",")
    |> Enum.map(&String.trim/1)

  config :thalamus, ThalamusWeb.Plugs.CORS,
    origins: origins,
    allow_credentials: true,
    max_age: 86400,
    expose_headers: ["x-ratelimit-limit", "x-ratelimit-remaining", "x-ratelimit-reset"]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :thalamus, Thalamus.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")
  public_port = if System.get_env("FORCE_SSL") == "true", do: 443, else: 80
  scheme = if System.get_env("FORCE_SSL") == "true", do: "https", else: "http"

  config :thalamus, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :thalamus, ThalamusWeb.Endpoint,
    url: [host: host, port: public_port, scheme: scheme],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :thalamus, ThalamusWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :thalamus, ThalamusWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # Email configuration for production
  config :thalamus, Thalamus.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("SMTP_RELAY"),
    username: System.get_env("SMTP_USERNAME"),
    password: System.get_env("SMTP_PASSWORD"),
    port: String.to_integer(System.get_env("SMTP_PORT", "587")),
    tls: String.to_atom(System.get_env("SMTP_TLS", "always")),
    auth: String.to_atom(System.get_env("SMTP_AUTH", "always")),
    retries: 2

  # Email sender configuration
  config :thalamus,
    from_email: System.get_env("FROM_EMAIL") || "noreply@#{host}",
    from_name: System.get_env("FROM_NAME") || "Thalamus OAuth2",
    base_url: "https://#{host}"
end

# ## Organization Plans Configuration
#
# Configure your organization subscription plans here.
# This configuration is environment-agnostic and can be customized
# to fit your specific business needs.
#
# If not configured, Thalamus will use default plans (free, starter, professional, enterprise).
#
# Example custom configuration:
#
# config :thalamus, :organization_plans,
#   # List of available plan types (atoms)
#   available_plans: [:basic, :premium, :enterprise],
#
#   # Default plan for new organizations
#   default_plan: :basic,
#
#   # Plan hierarchy for upgrades/downgrades (lowest to highest)
#   plan_hierarchy: [:basic, :premium, :enterprise],
#
#   # Plan configurations with limits and features
#   plan_configs: %{
#     basic: %{
#       max_users: 10,
#       max_api_calls_per_month: 50_000,
#       mfa_required: false,
#       sso_enabled: false,
#       audit_logs_retention_days: 30,
#       support_level: :email
#     },
#     premium: %{
#       max_users: 100,
#       max_api_calls_per_month: 500_000,
#       mfa_required: true,
#       sso_enabled: true,
#       audit_logs_retention_days: 90,
#       support_level: :priority
#     },
#     enterprise: %{
#       max_users: :unlimited,
#       max_api_calls_per_month: :unlimited,
#       mfa_required: true,
#       sso_enabled: true,
#       audit_logs_retention_days: 365,
#       support_level: :dedicated
#     }
#   }
#
# Note: If you don't provide this configuration, Thalamus will use
# default plans compatible with the existing ZEA setup.

# ## OAuth2 Scopes Configuration
#
# Configure your custom OAuth2 scopes here.
# Thalamus supports fully configurable scopes beyond standard OIDC scopes.
#
# Standard OIDC scopes are always available: openid, profile, email, address, phone, offline_access
#
# Example custom configuration:
#
# config :thalamus, :oauth2_scopes,
#   # Standard OIDC scopes (read-only, always included)
#   standard_scopes: ["openid", "profile", "email", "address", "phone", "offline_access"],
#
#   # Your custom application scopes
#   custom_scopes: [
#     "myapp:read",
#     "myapp:write",
#     "myapp:admin",
#     "api:access",
#     "data:read",
#     "data:write"
#   ],
#
#   # Scopes that require special permission/approval
#   restricted_scopes: [
#     "myapp:admin",
#     "data:write",
#     "offline_access"
#   ]
#
# Note: If you don't provide this configuration, Thalamus will use
# default scopes compatible with the existing ZEA setup.

# ## Feature Flags (Epic 8: Migration & Rollout)
#
# Configure feature flags for gradual rollout of new features.
# Flags can be set via environment variables or application config.
#
# Example with environment variables:
#
#     # Enable agent tokens globally
#     export ENABLE_AGENT_TOKENS=true
#
# Example with application config:
#
# config :thalamus, :feature_flags,
#   agent_tokens: true
#
# Per-organization flags can be set in the organizations.settings JSONB column:
#
#     UPDATE organizations
#     SET settings = jsonb_set(
#       COALESCE(settings, '{}'),
#       '{feature_flags,agent_tokens}',
#       'true'
#     )
#     WHERE id = 'org_123';
#
# Feature flag priority:
# 1. Environment variable (ENABLE_<FEATURE>)
# 2. Application config (:thalamus, :feature_flags, feature_name)
# 3. Per-organization setting (organizations.settings->feature_flags->feature_name)
# 4. Default (false)
