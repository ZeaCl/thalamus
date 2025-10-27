defmodule ThalamusWeb.Telemetry do
  @moduledoc """
  Telemetry supervisor and metrics definitions.

  Provides comprehensive metrics for:
  - HTTP requests (Phoenix)
  - Database queries (Ecto)
  - VM metrics (BEAM)
  - OAuth2 operations
  - Authentication events
  - MFA operations
  - Business metrics
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add Prometheus exporter or other reporters
      # {TelemetryMetricsPrometheus, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("thalamus.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("thalamus.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("thalamus.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("thalamus.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("thalamus.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # OAuth2 Metrics
      counter("thalamus.oauth2.token.generated",
        tags: [:grant_type],
        description: "Total OAuth2 tokens generated"
      ),
      counter("thalamus.oauth2.token.introspected",
        tags: [:active],
        description: "Total token introspection requests"
      ),
      counter("thalamus.oauth2.token.revoked",
        description: "Total tokens revoked"
      ),
      counter("thalamus.oauth2.authorization.approved",
        description: "Total authorizations approved"
      ),
      counter("thalamus.oauth2.authorization.denied",
        description: "Total authorizations denied"
      ),

      # Authentication Metrics
      counter("thalamus.auth.login.success",
        description: "Successful login attempts"
      ),
      counter("thalamus.auth.login.failed",
        tags: [:reason],
        description: "Failed login attempts"
      ),
      summary("thalamus.auth.login.duration",
        unit: {:native, :millisecond},
        description: "Login duration"
      ),

      # MFA Metrics
      counter("thalamus.mfa.setup.initiated",
        description: "MFA setup initiated"
      ),
      counter("thalamus.mfa.setup.completed",
        description: "MFA setup completed"
      ),
      counter("thalamus.mfa.verification.success",
        tags: [:method],
        description: "Successful MFA verifications"
      ),
      counter("thalamus.mfa.verification.failed",
        tags: [:method],
        description: "Failed MFA verifications"
      ),

      # Rate Limiting Metrics
      counter("thalamus.rate_limit.exceeded",
        tags: [:endpoint],
        description: "Rate limit exceeded count"
      ),

      # Business Metrics
      last_value("thalamus.users.total",
        description: "Total number of users"
      ),
      last_value("thalamus.users.active",
        description: "Number of active users"
      ),
      last_value("thalamus.organizations.total",
        description: "Total number of organizations"
      ),
      last_value("thalamus.oauth2_clients.total",
        description: "Total number of OAuth2 clients"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      {__MODULE__, :dispatch_business_metrics, []}
    ]
  end

  @doc """
  Dispatches business metrics periodically.
  Called every 10 seconds by telemetry_poller.
  """
  def dispatch_business_metrics do
    # User metrics
    user_count = count_users()
    active_user_count = count_active_users()

    :telemetry.execute(
      [:thalamus, :users, :total],
      %{value: user_count},
      %{}
    )

    :telemetry.execute(
      [:thalamus, :users, :active],
      %{value: active_user_count},
      %{}
    )

    # Organization metrics
    org_count = count_organizations()

    :telemetry.execute(
      [:thalamus, :organizations, :total],
      %{value: org_count},
      %{}
    )

    # OAuth2 Client metrics
    client_count = count_oauth2_clients()

    :telemetry.execute(
      [:thalamus, :oauth2_clients, :total],
      %{value: client_count},
      %{}
    )
  end

  # Business metric helpers
  defp count_users do
    try do
      Thalamus.Repo.aggregate("users", :count, :id)
    rescue
      _ -> 0
    end
  end

  defp count_active_users do
    try do
      import Ecto.Query

      Thalamus.Repo.one(
        from u in "users",
          where: u.status == ^"active",
          select: count(u.id)
      ) || 0
    rescue
      _ -> 0
    end
  end

  defp count_organizations do
    try do
      Thalamus.Repo.aggregate("organizations", :count, :id)
    rescue
      _ -> 0
    end
  end

  defp count_oauth2_clients do
    try do
      Thalamus.Repo.aggregate("oauth2_clients", :count, :id)
    rescue
      _ -> 0
    end
  end
end
