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
  alias Thalamus.DependencyBuilder

  @doc """
  POST /oauth/agent-token

  Generates an agent-specific access token with task-scoping and delegation tracking.

  ## Request Parameters

  - client_id (required): OAuth2 client identifier
  - client_secret (required): OAuth2 client secret
  - organization_id (required): Organization UUID
  - delegator_user_id (required): User ID of human authorizer
  - agent_type (required): "autonomous" | "supervisor" | "tool"
  - task_description (required): Human-readable description of the task
  - scope (required): Space-separated scopes (must be subset of client allowed_scopes)
  - task_id (optional): External task identifier (UUID)
  - parent_agent_id (optional): Parent agent token ID for delegation chains
  - expires_in (optional): Custom TTL in seconds (max 3600)
  - reason (optional): Human-readable reason/intent for audit trail

  ## Response

  Success (200):
  ```json
  {
    "access_token": "at_...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "scope": "read:data write:results",
    "agent_type": "autonomous",
    "task_id": "task_abc123",
    "task_description": "Process user documents",
    "delegation_depth": 0,
    "reason": "Automated document processing"
  }
  ```

  Error (400/401):
  ```json
  {
    "error": "invalid_request",
    "error_description": "delegator_user_id not found"
  }
  ```
  """
  def create(conn, params) do
    if Thalamus.FeatureFlags.agent_tokens_enabled?() do
      request = build_request(params)
      deps = DependencyBuilder.build_for_web(conn)

      case GenerateAgentToken.execute(request, deps) do
        {:ok, response} ->
          conn
          |> put_status(:ok)
          |> json(AgentTokenResponse.to_map(response))

        {:error, error} ->
          handle_error(conn, error)
      end
    else
      # Feature disabled - return 404 to avoid leaking feature existence
      conn
      |> put_status(:not_found)
      |> json(%{
        error: "not_found",
        error_description: "Endpoint not available"
      })
    end
  end

  # --- Private Functions ---

  defp build_request(params) do
    %AgentTokenRequest{
      client_id: get_param(params, "client_id"),
      client_secret: get_param(params, "client_secret"),
      organization_id: get_param(params, "organization_id"),
      delegator_user_id: get_param(params, "delegator_user_id"),
      agent_type: get_param(params, "agent_type"),
      task_id: get_param(params, "task_id"),
      task_description: get_param(params, "task_description"),
      scopes: parse_scopes(get_param(params, "scope", "")),
      parent_agent_id: get_param(params, "parent_agent_id"),
      expires_in: parse_int(get_param(params, "expires_in")),
      reason: get_param(params, "reason")
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

  defp handle_error(conn, :missing_client_id) do
    error_response(conn, :bad_request, "invalid_request", "client_id is required")
  end

  defp handle_error(conn, :missing_client_secret) do
    error_response(conn, :bad_request, "invalid_request", "client_secret is required")
  end

  defp handle_error(conn, :missing_organization_id) do
    error_response(conn, :bad_request, "invalid_request", "organization_id is required")
  end

  defp handle_error(conn, :missing_delegator_user_id) do
    error_response(conn, :bad_request, "invalid_request", "delegator_user_id is required")
  end

  defp handle_error(conn, :invalid_delegator_user_id) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "delegator_user_id must be a valid UUID"
    )
  end

  defp handle_error(conn, :missing_agent_type) do
    error_response(conn, :bad_request, "invalid_request", "agent_type is required")
  end

  defp handle_error(conn, :invalid_agent_type) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "agent_type must be autonomous, supervisor, or tool"
    )
  end

  defp handle_error(conn, :missing_task_description) do
    error_response(conn, :bad_request, "invalid_request", "task_description is required")
  end

  defp handle_error(conn, :empty_task_description) do
    error_response(conn, :bad_request, "invalid_request", "task_description cannot be empty")
  end

  defp handle_error(conn, :empty_scopes) do
    error_response(conn, :bad_request, "invalid_scope", "scope parameter is required")
  end

  defp handle_error(conn, :invalid_scopes) do
    error_response(conn, :bad_request, "invalid_scope", "requested scopes not allowed for client")
  end

  defp handle_error(conn, :ttl_exceeds_maximum) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "expires_in cannot exceed 3600 seconds"
    )
  end

  defp handle_error(conn, :invalid_expires_in) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "expires_in must be a positive integer"
    )
  end

  defp handle_error(conn, :invalid_parent_agent_id) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "parent_agent_id must be a valid UUID"
    )
  end

  defp handle_error(conn, :invalid_client_credentials) do
    error_response(conn, :unauthorized, "invalid_client", "client authentication failed")
  end

  defp handle_error(conn, :client_inactive) do
    error_response(conn, :unauthorized, "invalid_client", "client is inactive")
  end

  defp handle_error(conn, :organization_mismatch) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "client does not belong to specified organization"
    )
  end

  defp handle_error(conn, :delegator_not_found) do
    error_response(conn, :bad_request, "invalid_request", "delegator_user_id not found")
  end

  defp handle_error(conn, :delegator_not_active) do
    error_response(conn, :bad_request, "invalid_request", "delegating user is not active")
  end

  defp handle_error(conn, :delegator_organization_mismatch) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "delegator does not belong to specified organization"
    )
  end

  defp handle_error(conn, :organization_not_found) do
    error_response(conn, :bad_request, "invalid_request", "organization not found")
  end

  defp handle_error(conn, :organization_not_active) do
    error_response(conn, :bad_request, "invalid_request", "organization is not active")
  end

  defp handle_error(conn, :parent_token_not_found) do
    error_response(conn, :bad_request, "invalid_request", "parent_agent_id not found")
  end

  defp handle_error(conn, :parent_token_not_active) do
    error_response(conn, :bad_request, "invalid_request", "parent agent token is not active")
  end

  defp handle_error(conn, :max_delegation_depth_exceeded) do
    error_response(
      conn,
      :bad_request,
      "invalid_request",
      "delegation chain exceeds maximum depth of 4"
    )
  end

  defp handle_error(conn, :not_found) do
    error_response(conn, :unauthorized, "invalid_client", "client authentication failed")
  end

  defp handle_error(conn, _error) do
    error_response(conn, :internal_server_error, "server_error", "an internal error occurred")
  end

  # Stripe-level error response format
  defp error_response(conn, status, error_code, message) do
    request_id = conn.assigns[:request_id] || generate_request_id()

    conn
    |> put_status(status)
    |> json(%{
      error: %{
        code: error_code,
        message: message,
        documentation_url: documentation_url(error_code),
        request_id: request_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        details: %{}
      }
    })
  end

  defp documentation_url(error_code) do
    base_url = Application.get_env(:thalamus, :docs_base_url, "https://docs.thalamus.io")
    "#{base_url}/errors/#{error_code}"
  end

  defp generate_request_id do
    "req_" <>
      (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false) |> binary_part(0, 20))
  end
end
