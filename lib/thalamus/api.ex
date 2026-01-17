defmodule Thalamus.API do
  @moduledoc """
  Public API for Thalamus - Callable directly from Elixir code or via HTTP.

  This is the **ONLY** public interface for Thalamus. All other modules are internal
  implementation details and should not be called directly.

  ## Use Cases

  ### 1. Umbrella App Integration (Cerebelum)

  Cerebelum workflow engine can call Thalamus directly via this module:

      # Generate agent token
      {:ok, response} = Thalamus.API.generate_agent_token(%{
        client_id: "client_123",
        client_secret: "secret",
        organization_id: "org_abc",
        delegator_user_id: "user_456",
        agent_type: "autonomous",
        task_id: "task_789",
        scopes: ["email:send", "calendar:read"]
      })

      # Validate step authorization (called before EACH workflow step)
      {:ok, %{authorized: true}} = Thalamus.API.validate_step(
        response.access_token,
        "send_email_step",
        ["email:send"]
      )

  ### 2. External HTTP Integration

  External services call Thalamus via HTTP endpoints that use this API internally.

  ### 3. Testing

  Tests can call this API directly without HTTP overhead.

  ## Architecture

  This module follows the Facade pattern:
  - Provides simple interface to complex subsystem (use cases, repositories, etc.)
  - Handles dependency injection internally
  - Converts between external params and internal DTOs
  - Single point of entry for all Thalamus operations

  ## Stability Guarantee

  This API is **stable** - breaking changes will follow semantic versioning.
  Internal modules (use cases, repositories, etc.) may change without notice.
  """

  alias Thalamus.DependencyBuilder
  alias Thalamus.Application.UseCases.{
    GenerateAgentToken,
    ValidateStepAuthorization,
    RevokeAgentToken
  }

  alias Thalamus.Application.DTOs.AgentTokenRequest

  # Public Functions

  @doc """
  Generates an agent token for AI workflow automation.

  ## Parameters

  Map with the following keys:
  - `client_id` (required) - OAuth2 client ID
  - `client_secret` (required) - OAuth2 client secret
  - `organization_id` (required) - Organization UUID
  - `delegator_user_id` (required) - User delegating permissions to agent
  - `agent_type` (required) - Type: "autonomous", "supervisor", or "tool"
  - `task_id` (required) - Unique task identifier
  - `scopes` (required) - List of permission scopes (e.g., ["email:send"])
  - `task_description` (optional) - Human-readable task description
  - `expires_in` (optional) - TTL in seconds (default: 3600, max: 3600)
  - `parent_agent_id` (optional) - Parent token for delegation chains
  - `reason` (optional) - Reason for token generation

  ## Returns

  - `{:ok, response}` - Token generated successfully
  - `{:error, reason}` - Generation failed

  ## Examples

      # Root agent token (no parent)
      {:ok, response} = Thalamus.API.generate_agent_token(%{
        client_id: "client_abc123",
        client_secret: "secret_xyz789",
        organization_id: "org_acme_corp",
        delegator_user_id: "user_bob_456",
        agent_type: "autonomous",
        task_id: "task_send_weekly_report",
        scopes: ["email:send", "reports:read"],
        task_description: "Send weekly sales report to team",
        expires_in: 1800  # 30 minutes
      })

      # Access the token
      token = response.access_token  # "at_abc123..."
      expires_in = response.expires_in  # 1800

      # Child agent token (delegation chain)
      {:ok, child_response} = Thalamus.API.generate_agent_token(%{
        # ... same fields ...
        parent_agent_id: response.agent_id,  # Creates delegation chain
        scopes: ["email:send"],  # Must be subset of parent scopes
        expires_in: 900  # Must be ≤ parent's remaining TTL
      })

  ## Response Format

      %{
        access_token: "at_abc123...",
        token_type: "Bearer",
        expires_in: 1800,
        agent_id: "agt_xyz789",
        agent_type: "autonomous",
        task_id: "task_send_weekly_report",
        task_description: "Send weekly sales report to team",
        scopes: ["email:send", "reports:read"],
        delegation_depth: 0,
        delegator_user_id: "user_bob_456",
        organization_id: "org_acme_corp"
      }

  ## Errors

  - `:invalid_client_credentials` - client_id/client_secret mismatch
  - `:client_not_found` - OAuth2 client doesn't exist
  - `:delegator_not_found` - Delegator user doesn't exist
  - `:organization_not_active` - Organization is inactive
  - `:invalid_scopes` - Scopes not allowed by client
  - `:max_delegation_depth_exceeded` - Delegation chain too deep (max 4)
  - `:child_ttl_exceeds_parent` - Child TTL > parent's remaining TTL
  """
  @spec generate_agent_token(map()) :: {:ok, map()} | {:error, atom()}
  def generate_agent_token(params) when is_map(params) do
    with {:ok, request} <- build_agent_token_request(params),
         deps <- DependencyBuilder.build_default() do
      case GenerateAgentToken.execute(request, deps) do
        {:ok, response} -> {:ok, Map.from_struct(response)}
        error -> error
      end
    end
  end

  @doc """
  Validates if a token can execute a specific workflow step.

  Called by Cerebelum **before** executing EACH step in a workflow.

  ## Parameters

  - `token` - Access token string (e.g., "at_abc123...")
  - `step_name` - Workflow step identifier (e.g., "send_email_step")
  - `required_scopes` - Scopes needed for this step (e.g., ["email:send"])
  - `context` (optional) - Workflow context metadata

  ## Returns

  - `{:ok, %{authorized: true, ...}}` - Step can execute
  - `{:error, reason}` - Step cannot execute

  ## Examples

      # Before executing "send_email" step
      token = agent_token.access_token

      case Thalamus.API.validate_step(token, "send_email", ["email:send"]) do
        {:ok, %{authorized: true}} ->
          # Execute step
          send_email(recipient, subject, body)

        {:error, :insufficient_scopes} ->
          # Deny step execution
          {:error, "Agent lacks email:send permission"}

        {:error, :token_expired} ->
          # Token expired
          {:error, "Agent token has expired"}
      end

  ## Response Format

      %{
        authorized: true,
        agent_id: "agt_xyz789",
        agent_type: "autonomous",
        scopes: ["email:send", "email:read", "calendar:read"]
      }

  ## Errors

  - `:token_not_found` - Token doesn't exist
  - `:token_expired` - Token has expired
  - `:token_revoked` - Token has been revoked
  - `:insufficient_scopes` - Token lacks required scopes
  - `:invalid_token_format` - Token format invalid
  """
  @spec validate_step(String.t(), String.t(), [String.t()], map()) ::
          {:ok, map()} | {:error, atom()}
  def validate_step(token, step_name, required_scopes, context \\ %{})
      when is_binary(token) and is_binary(step_name) and is_list(required_scopes) do
    request = %{
      token: token,
      step_name: step_name,
      required_scopes: required_scopes,
      workflow_context: context
    }

    deps = DependencyBuilder.build_default()
    ValidateStepAuthorization.execute(request, deps)
  end

  @doc """
  Revokes an agent token.

  ## Parameters

  - `token_id` - Agent token UUID to revoke
  - `params` - Optional parameters:
    - `:cascade` - Revoke entire delegation chain (default: false)
    - `:revoked_by` - User ID who revoked the token
    - `:reason` - Reason for revocation
    - `:organization_id` - Organization ID (for multi-tenant validation)

  ## Returns

  - `{:ok, result}` - Token revoked successfully
  - `{:error, reason}` - Revocation failed

  ## Examples

      # Revoke single token
      {:ok, _} = Thalamus.API.revoke_token("agt_abc123", %{
        revoked_by: "user_admin_789",
        reason: "Task completed"
      })

      # Revoke entire delegation chain
      {:ok, result} = Thalamus.API.revoke_token("agt_parent_123", %{
        cascade: true,
        revoked_by: "user_admin_789",
        reason: "Security incident - revoke all child tokens"
      })

      # result.revoked_count => 5 (parent + 4 children)

  ## Response Format

      %{
        revoked_token_id: "agt_abc123",
        revoked_count: 1,  # or 5 if cascade: true
        revoked_at: ~U[2026-01-17 18:30:00Z]
      }

  ## Errors

  - `:token_not_found` - Token doesn't exist
  - `:already_revoked` - Token already revoked
  - `:organization_mismatch` - Token belongs to different organization
  """
  @spec revoke_token(binary(), map()) :: {:ok, map()} | {:error, atom()}
  def revoke_token(token_id, params \\ %{}) when is_binary(token_id) do
    request = build_revoke_token_request(token_id, params)
    deps = DependencyBuilder.build_default()

    RevokeAgentToken.execute(request, deps)
  end

  @doc """
  Introspects a token to get its metadata.

  Similar to RFC 7662 token introspection.

  ## Parameters

  - `token` - Access token string or token UUID

  ## Returns

  - `{:ok, metadata}` - Token metadata
  - `{:error, reason}` - Introspection failed

  ## Examples

      {:ok, metadata} = Thalamus.API.introspect_token("at_abc123...")

      # metadata:
      %{
        active: true,
        agent_id: "agt_xyz789",
        agent_type: "autonomous",
        scopes: ["email:send", "calendar:read"],
        expires_at: ~U[2026-01-17 19:00:00Z],
        delegator_user_id: "user_bob_456",
        organization_id: "org_acme_corp"
      }

  ## Response Format (Active Token)

      %{
        active: true,
        agent_id: "agt_xyz789",
        agent_type: "autonomous",
        task_id: "task_send_report",
        scopes: ["email:send"],
        expires_at: ~U[2026-01-17 19:00:00Z],
        issued_at: ~U[2026-01-17 18:00:00Z],
        delegator_user_id: "user_bob_456",
        organization_id: "org_acme_corp",
        delegation_depth: 1
      }

  ## Response Format (Inactive Token)

      %{active: false}
  """
  @spec introspect_token(String.t()) :: {:ok, map()} | {:error, atom()}
  def introspect_token(token) when is_binary(token) do
    # TODO: Implement token introspection
    # This will be implemented in Epic 4 (Infrastructure Layer)
    {:error, :not_implemented}
  end

  # Private Functions

  @spec build_agent_token_request(map()) :: {:ok, AgentTokenRequest.t()} | {:error, atom()}
  defp build_agent_token_request(params) do
    # Convert string keys to atoms if needed
    params = atomize_keys(params)

    # Build AgentTokenRequest struct
    try do
      request = struct!(AgentTokenRequest, params)
      {:ok, request}
    rescue
      ArgumentError -> {:error, :invalid_params}
      KeyError -> {:error, :missing_required_fields}
    end
  end

  @spec build_revoke_token_request(binary(), map()) :: map()
  defp build_revoke_token_request(token_id, params) do
    params = atomize_keys(params)

    %{
      token_id: token_id,
      cascade: Map.get(params, :cascade, false),
      revoked_by: Map.get(params, :revoked_by),
      reason: Map.get(params, :reason),
      organization_id: Map.get(params, :organization_id)
    }
  end

  @spec atomize_keys(map()) :: map()
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      {key, value} when is_atom(key) -> {key, value}
    end)
  rescue
    ArgumentError -> map
  end
end
