defmodule Thalamus.MixProject do
  use Mix.Project

  def project do
    [
      app: :thalamus,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Thalamus.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix Framework
      {:phoenix, "~> 1.8.0"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # OAuth2 & JWT
      {:joken, "~> 2.6"},
      {:jose, "~> 1.11"},
      {:guardian, "~> 2.3"},

      # Cryptography & Security
      {:bcrypt_elixir, "~> 3.0"},
      {:pbkdf2_elixir, "~> 2.0"},
      {:comeonin, "~> 5.3"},
      {:cloak_ecto, "~> 1.3"},
      # TOTP for MFA
      {:pot, "~> 1.0"},

      # SAML SSO
      {:samly, "~> 1.4"},

      # HTTP Client
      {:req, "~> 0.4"},
      {:finch, "~> 0.18"},

      # Caching
      {:cachex, "~> 3.6"},
      {:redix, "~> 1.2"},

      # Rate Limiting
      {:hammer, "~> 6.2"},

      # Background Jobs
      {:oban, "~> 2.17"},

      # Email
      {:swoosh, "~> 1.16"},
      {:gen_smtp, "~> 1.2"},

      # Validation & Data Structures
      {:vex, "~> 0.9"},
      {:ecto_enum, "~> 1.4"},

      # Utilities
      {:timex, "~> 3.7"},
      {:uuid, "~> 1.1"},
      {:decimal, "~> 2.0"},
      {:csv, "~> 3.2"},

      # Development & Testing
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.18", only: :test},

      # Monitoring & Observability
      {:sentry, "~> 10.1"},
      # {:new_relic_agent, "~> 1.0"},  # Temporarily disabled due to Elixir 1.18.4 compatibility
      {:prometheus_ex, "~> 3.1"},

      # Documentation
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      # Unit tests without database setup
      "test.unit": ["test"],
      "test.integration": ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      # Test coverage
      "test.coverage": ["ecto.create --quiet", "ecto.migrate --quiet", "coveralls.html"],
      "test.coverage.ci": ["ecto.create --quiet", "ecto.migrate --quiet", "coveralls"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind thalamus", "esbuild thalamus"],
      "assets.deploy": [
        "tailwind thalamus --minify",
        "esbuild thalamus --minify",
        "phx.digest"
      ],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
