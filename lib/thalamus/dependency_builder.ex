defmodule Thalamus.DependencyBuilder do
  @moduledoc """
  Builds dependency maps for use cases across different contexts.

  This module centralizes dependency injection configuration, making it easy to:
  - Build deps for web controllers
  - Build deps for direct API calls (Cerebelum integration)
  - Build deps for tests (with mocks)

  ## Usage

      # In web controllers
      deps = DependencyBuilder.build_for_web(conn)
      GenerateAgentToken.execute(request, deps)

      # In Thalamus.API (Cerebelum integration)
      deps = DependencyBuilder.build_default()
      GenerateAgentToken.execute(request, deps)

      # In tests (with Mox)
      deps = DependencyBuilder.build_for_tests()
      GenerateAgentToken.execute(request, deps)

  ## Architecture

  This follows the Dependency Inversion Principle (SOLID):
  - Use cases depend on ports (behaviours), not implementations
  - This module wires concrete implementations to ports
  - Different contexts can use different implementations
  """

  alias Thalamus.Infrastructure.Repositories.{
    PostgresqlOAuth2ClientRepository,
    PostgresqlUserRepository,
    PostgresqlAgentTokenRepository,
    PostgresqlOrganizationRepository
  }

  alias Thalamus.Infrastructure.Adapters.AuditLoggerImpl

  @type deps :: %{
          required(:client_repository) => module(),
          required(:user_repository) => module(),
          required(:agent_token_repository) => module(),
          required(:organization_repository) => module(),
          required(:audit_logger) => module(),
          optional(:context) => map()
        }

  @doc """
  Builds default dependencies for production use.

  Uses PostgreSQL repositories and production audit logger.
  No request context included.

  ## Examples

      iex> deps = DependencyBuilder.build_default()
      iex> Map.has_key?(deps, :client_repository)
      true
  """
  @spec build_default() :: deps()
  def build_default do
    %{
      client_repository: PostgresqlOAuth2ClientRepository,
      user_repository: PostgresqlUserRepository,
      agent_token_repository: PostgresqlAgentTokenRepository,
      organization_repository: PostgresqlOrganizationRepository,
      audit_logger: AuditLoggerImpl
    }
  end

  @doc """
  Builds dependencies with request context for web requests.

  Includes HTTP request metadata (IP, user agent, request ID) for audit logging.

  ## Examples

      def create(conn, params) do
        deps = DependencyBuilder.build_for_web(conn)
        GenerateAgentToken.execute(request, deps)
      end
  """
  @spec build_for_web(Plug.Conn.t()) :: deps()
  def build_for_web(conn) do
    context = extract_request_context(conn)

    build_default()
    |> Map.put(:context, context)
  end

  @doc """
  Builds dependencies for Cerebelum integration.

  Currently identical to build_default/0 but kept separate for future
  customization (e.g., different audit logger, caching strategy).

  ## Examples

      # In Cerebelum workflow engine
      deps = DependencyBuilder.build_for_cerebelum()
      Thalamus.API.generate_agent_token(params, deps)
  """
  @spec build_for_cerebelum() :: deps()
  def build_for_cerebelum do
    build_default()
  end

  @doc """
  Builds dependencies for tests with mock modules.

  Returns a map with module names that can be configured with Mox.
  Tests should override with specific mocks as needed.

  ## Examples

      # In test setup
      setup do
        deps = DependencyBuilder.build_for_tests()
        {:ok, deps: deps}
      end

      # In test, override specific mocks
      test "generates token", %{deps: deps} do
        deps = %{deps | client_repository: MockClientRepository}
        # ...
      end
  """
  @spec build_for_tests() :: deps()
  def build_for_tests do
    %{
      client_repository: Thalamus.MockClientRepository,
      user_repository: Thalamus.MockUserRepository,
      agent_token_repository: Thalamus.MockAgentTokenRepository,
      organization_repository: Thalamus.MockOrganizationRepository,
      audit_logger: Thalamus.MockAuditLogger
    }
  end

  # Private Functions

  @spec extract_request_context(Plug.Conn.t()) :: map()
  defp extract_request_context(conn) do
    %{
      ip_address: get_ip_address(conn),
      user_agent: get_user_agent(conn),
      request_id: get_request_id(),
      environment: Application.get_env(:thalamus, :env, :dev)
    }
  end

  @spec get_ip_address(Plug.Conn.t()) :: String.t()
  defp get_ip_address(conn) do
    # Check X-Forwarded-For header first (for proxies/load balancers)
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip_list | _] ->
        # X-Forwarded-For can have multiple IPs, take the first (original client)
        ip_list
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fallback to remote_ip from connection
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end

  @spec get_user_agent(Plug.Conn.t()) :: String.t()
  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      [] -> "unknown"
    end
  end

  @spec get_request_id() :: String.t() | nil
  defp get_request_id do
    # Get request_id from Logger metadata (set by Phoenix)
    Logger.metadata()[:request_id]
  end
end
