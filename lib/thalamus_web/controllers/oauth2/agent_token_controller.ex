defmodule ThalamusWeb.OAuth2.AgentTokenController do
  @moduledoc """
  Controller for agent-specific OAuth2 access tokens.

  Handles the generation of tokens with task-scoping, delegation tracking,
  and compliance-ready audit trails for AI agents.

  SOLID Principles Applied:
  - Single Responsibility: Only handles agent token HTTP requests
  - Dependency Inversion: Depends on use cases, not implementations
  """

  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.GenerateAgentToken
  alias Thalamus.Application.DTOs.{AgentTokenRequest, AgentTokenResponse}

  # Dependencies
  @deps %{
    client_repository: Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepository,
    user_repository: Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository,
    token_repository: Thalamus.Infrastructure.Repositories.PostgreSQLTokenRepository,
    audit_logger: Thalamus.Infrastructure.Adapters.AuditLoggerImpl
  }

  @doc """
  POST /oauth/agent-token

  Generates an agent-specific access token with task-scoping and delegation tracking.

  ## Request Parameters

  - client_id (required): OAuth2 client identifier
  - client_secret (required): OAuth2 client secret
  - delegated_by_user_id (required): User ID of human authorizer
  - agent_type (required): "autonomous" | "supervised" | "ephemeral"
  - scope (required): Space-separated scopes (must be subset of client allowed_scopes)
  - task_id (optional): External task identifier
  - task_type (optional): Task classification
  - max_operations (optional): Maximum number of token uses
  - expires_on_completion (optional): Auto-revoke when max_operations reached (default: false)
  - intent_description (optional): Human-readable intent for compliance
  - orchestrator_id (optional): Orchestrator instance identifier
  - expires_in (optional): Custom TTL in seconds (max 3600)

  ## Response

  Success (200):
  ```json
  {
    "access_token": "at_...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "scope": "corpus:read corpus:write",
    "agent_type": "autonomous",
    "task_id": "task_abc123",
    "max_operations": 100,
    "expires_on_completion": true
  }
  ```

  Error (400/401):
  ```json
  {
    "error": "invalid_request",
    "error_description": "delegated_by_user_id not found"
  }
  ```
  """
  def create(conn, params) do
    request = build_request(params)

    case GenerateAgentToken.execute(request, @deps) do
      {:ok, response} ->
        conn
        |> put_status(:ok)
        |> json(AgentTokenResponse.to_map(response))

      {:error, error} ->
        handle_error(conn, error)
    end
  end

  # --- Private Functions ---

  defp build_request(params) do
    %AgentTokenRequest{
      client_id: get_param(params, "client_id"),
      client_secret: get_param(params, "client_secret"),
      delegated_by_user_id: get_param(params, "delegated_by_user_id"),
      agent_type: get_param(params, "agent_type"),
      task_id: get_param(params, "task_id"),
      task_type: get_param(params, "task_type"),
      task_scopes: parse_scopes(get_param(params, "scope", "")),
      max_operations: parse_int(get_param(params, "max_operations")),
      expires_on_completion: parse_bool(get_param(params, "expires_on_completion", false)),
      intent_description: get_param(params, "intent_description"),
      orchestrator_id: get_param(params, "orchestrator_id"),
      ttl: parse_int(get_param(params, "expires_in"))
    }
  end

  defp get_param(params, key, default \\ nil) do
    Map.get(params, key, default)
  end

  defp parse_scopes(""), do: []

  defp parse_scopes(scope_string) when is_binary(scope_string) do
    scope_string
    |> String.split(" ", trim: true)
    |> Enum.uniq()
  end

  defp parse_scopes(_), do: []

  defp parse_int(nil), do: nil

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(_), do: nil

  defp parse_bool(nil), do: false
  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(true), do: true
  defp parse_bool(false), do: false
  defp parse_bool(_), do: false

  defp handle_error(conn, :missing_client_id) do
    error_response(conn, :bad_request, "invalid_request", "client_id is required")
  end

  defp handle_error(conn, :missing_client_secret) do
    error_response(conn, :bad_request, "invalid_request", "client_secret is required")
  end

  defp handle_error(conn, :missing_delegated_by_user_id) do
    error_response(conn, :bad_request, "invalid_request", "delegated_by_user_id is required")
  end

  defp handle_error(conn, :missing_agent_type) do
    error_response(conn, :bad_request, "invalid_request", "agent_type is required")
  end

  defp handle_error(conn, :invalid_agent_type) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "agent_type must be autonomous, supervised, or ephemeral"
    )
  end

  defp handle_error(conn, :invalid_client) do
    error_response(conn, :unauthorized, "invalid_client", "client authentication failed")
  end

  defp handle_error(conn, :client_inactive) do
    error_response(conn, :unauthorized, "invalid_client", "client is inactive")
  end

  defp handle_error(conn, :delegator_not_found) do
    error_response(conn, :bad_request, "invalid_request", "delegated_by_user_id not found")
  end

  defp handle_error(conn, :delegator_inactive) do
    error_response(conn, :bad_request, "invalid_request", "delegating user is inactive")
  end

  defp handle_error(conn, :empty_task_scopes) do
    error_response(conn, :bad_request, "invalid_scope", "scope parameter is required")
  end

  defp handle_error(conn, {:invalid_task_scopes, invalid_scopes}) do
    description = "invalid scopes: #{Enum.join(invalid_scopes, ", ")}"
    error_response(conn, :bad_request, "invalid_scope", description)
  end

  defp handle_error(conn, :invalid_ttl) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "expires_in must be between 1 and 3600 seconds"
    )
  end

  defp handle_error(conn, :invalid_user_id_in_chain) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "delegated_by_user_id must be a valid UUID"
    )
  end

  defp handle_error(conn, :delegation_chain_too_deep) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "delegation chain exceeds maximum depth"
    )
  end

  defp handle_error(conn, :empty_delegation_chain) do
    error_response(conn, :bad_request, "invalid_request", "delegation chain cannot be empty")
  end

  defp handle_error(conn, :not_found) do
    error_response(conn, :unauthorized, "invalid_client", "client authentication failed")
  end

  defp handle_error(conn, _error) do
    error_response(conn, :internal_server_error, "server_error", "an internal error occurred")
  end

  defp error_response(conn, status, error, description) do
    conn
    |> put_status(status)
    |> json(%{
      error: error,
      error_description: description
    })
  end
end
