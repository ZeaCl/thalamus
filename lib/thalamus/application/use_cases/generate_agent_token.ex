defmodule Thalamus.Application.UseCases.GenerateAgentToken do
  @moduledoc """
  Use case for generating agent-specific access tokens with task-scoping and delegation tracking.

  SOLID Principles:
  - Single Responsibility: Only handles agent token generation
  - Dependency Inversion: Depends on ports (repositories), not implementations
  - Open/Closed: Extensible without modifying existing OAuth2 token generation

  ## Features

  - Task-scoped tokens with delegation chain tracking
  - Multi-tenant isolation via organization_id
  - Compliance-ready audit trails
  - Automatic delegation chain inheritance
  - Maximum delegation depth enforcement (4 levels)

  ## Security Considerations

  - Validates delegator exists and is active
  - Enforces scopes as strict subset of client.allowed_scopes
  - Maximum TTL of 3600 seconds (1 hour) for agent tokens
  - Validates parent agent token if creating delegated token
  - Logs all agent token creations with full context
  """

  require Logger

  alias Thalamus.Application.DTOs.{AgentTokenRequest, AgentTokenResponse}
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}
  alias Thalamus.Application.Ports.AgentTokenRepository

  @type deps :: %{
          required(:client_repository) => module(),
          required(:user_repository) => module(),
          required(:agent_token_repository) => module(),
          required(:audit_logger) => module(),
          optional(:organization_repository) => module()
        }

  @doc """
  Executes agent token generation.

  ## Flow

  1. Validate request structure
  2. Authenticate OAuth2 client (M2M)
  3. Validate delegator user exists and is active
  4. Validate organization exists and is active
  5. Validate scopes are subset of client.allowed_scopes
  6. Build delegation chain (from parent or create new)
  7. Create AgentToken domain entity
  8. Save token via repository
  9. Log audit event
  10. Return token response

  ## Examples

      iex> request = %AgentTokenRequest{
      ...>   client_id: "client_abc",
      ...>   client_secret: "secret",
      ...>   organization_id: "org_123",
      ...>   delegator_user_id: "user_123",
      ...>   agent_type: "autonomous",
      ...>   task_description: "Process documents",
      ...>   scopes: ["read:documents"]
      ...> }
      iex> GenerateAgentToken.execute(request, deps)
      {:ok, %AgentTokenResponse{access_token: "at_...", ...}}
  """
  @spec execute(AgentTokenRequest.t(), deps()) ::
          {:ok, AgentTokenResponse.t()} | {:error, atom()}
  def execute(%AgentTokenRequest{} = request, deps) do
    with :ok <- AgentTokenRequest.validate(request),
         {:ok, client} <- authenticate_client(request, deps),
         {:ok, delegator} <- validate_delegator(request, deps),
         {:ok, _organization} <- validate_organization(request, deps),
         :ok <- validate_scopes_subset(request.scopes, client.allowed_scopes),
         {:ok, agent_type} <- AgentType.new(request.agent_type),
         {:ok, task_id} <- parse_or_generate_task_id(request.task_id),
         {:ok, delegation_chain} <- build_delegation_chain(request, deps),
         {:ok, agent_token} <-
           create_agent_token(request, client, delegator, agent_type, task_id, delegation_chain),
         {:ok, saved_token} <- save_token(agent_token, deps),
         :ok <- log_token_creation(saved_token, request, deps) do
      # Get the access token from the database schema
      {:ok, schema} = get_schema_for_access_token(saved_token.id)

      response = AgentTokenResponse.from_domain(saved_token, schema.access_token)
      {:ok, response}
    end
  end

  # Authenticates OAuth2 client using M2M credentials
  defp authenticate_client(%AgentTokenRequest{} = request, deps) do
    with {:ok, client} <- deps.client_repository.find_by_client_id(request.client_id),
         true <- client.is_active || {:error, :client_inactive},
         true <-
           verify_client_secret(request.client_secret, client.client_secret) ||
             {:error, :invalid_client_credentials},
         true <-
           client.organization_id == request.organization_id || {:error, :organization_mismatch} do
      {:ok, client}
    else
      {:error, :not_found} -> {:error, :invalid_client_credentials}
      {:error, reason} -> {:error, reason}
      false -> {:error, :invalid_client_credentials}
    end
  end

  # Verifies client secret using constant-time comparison
  defp verify_client_secret(provided_secret, stored_secret) do
    Bcrypt.verify_pass(provided_secret, stored_secret)
  end

  # Validates delegator user exists and is active
  defp validate_delegator(%AgentTokenRequest{} = request, deps) do
    with {:ok, user} <- deps.user_repository.find_by_id(request.delegator_user_id),
         true <- user.status == :active || {:error, :delegator_not_active},
         true <-
           user.organization_id == request.organization_id ||
             {:error, :delegator_organization_mismatch} do
      {:ok, user}
    else
      {:error, :not_found} -> {:error, :delegator_not_found}
      {:error, reason} -> {:error, reason}
      false -> {:error, :delegator_not_active}
    end
  end

  # Validates organization exists and is active
  defp validate_organization(%AgentTokenRequest{organization_id: org_id}, deps) do
    # If organization_repository is not provided, skip validation
    # (for backwards compatibility or testing)
    if Map.has_key?(deps, :organization_repository) do
      with {:ok, org} <- deps.organization_repository.find_by_id(org_id),
           true <- org.status == :active || {:error, :organization_not_active} do
        {:ok, org}
      else
        {:error, :not_found} -> {:error, :organization_not_found}
        {:error, reason} -> {:error, reason}
        false -> {:error, :organization_not_active}
      end
    else
      # Skip organization validation
      {:ok, nil}
    end
  end

  # Validates that requested scopes are a subset of client's allowed scopes
  defp validate_scopes_subset(requested_scopes, allowed_scopes) do
    requested_set = MapSet.new(requested_scopes)
    allowed_set = MapSet.new(allowed_scopes)

    if MapSet.subset?(requested_set, allowed_set) do
      :ok
    else
      {:error, :invalid_scopes}
    end
  end

  # Parses task_id from request or generates new one if not provided
  defp parse_or_generate_task_id(nil) do
    TaskId.new(Ecto.UUID.generate())
  end

  defp parse_or_generate_task_id(task_id_string) do
    TaskId.new(task_id_string)
  end

  # Builds delegation chain from parent agent or creates root chain
  defp build_delegation_chain(%AgentTokenRequest{parent_agent_id: nil}, _deps) do
    # Root token - no parent
    DelegationChain.new(%{
      parent_token_id: nil,
      depth: 0,
      path: []
    })
  end

  defp build_delegation_chain(%AgentTokenRequest{parent_agent_id: parent_id}, deps) do
    with {:ok, parent_token} <- deps.agent_token_repository.find_by_id(parent_id),
         true <- parent_token.status == :active || {:error, :parent_token_not_active},
         {:ok, child_chain} <-
           DelegationChain.add_delegation(parent_token.delegation_chain, parent_id) do
      {:ok, child_chain}
    else
      {:error, :not_found} -> {:error, :parent_token_not_found}
      {:error, reason} -> {:error, reason}
      false -> {:error, :parent_token_not_active}
    end
  end

  # Creates AgentToken domain entity
  defp create_agent_token(request, client, delegator, agent_type, task_id, delegation_chain) do
    params = %{
      client_id: client.id,
      organization_id: request.organization_id,
      agent_type: agent_type,
      task_id: task_id,
      task_description: request.task_description,
      scopes: request.scopes,
      delegation_chain: delegation_chain,
      delegator_user_id: delegator.id,
      expires_in: AgentTokenRequest.get_expires_in(request),
      reason: request.reason
    }

    AgentToken.create(params)
  end

  # Saves token using repository
  defp save_token(agent_token, deps) do
    deps.agent_token_repository.save(agent_token)
  end

  # Temporary helper to get schema for access_token (until we refactor repository)
  defp get_schema_for_access_token(token_id) do
    alias Thalamus.Infrastructure.Persistence.Schemas.AgentTokenSchema
    alias Thalamus.Repo

    case Repo.get(AgentTokenSchema, token_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end

  # Logs token creation to audit log
  defp log_token_creation(token, request, deps) do
    deps.audit_logger.log(%{
      event_type: "agent_token.created",
      actor_type: "oauth2_client",
      actor_id: request.client_id,
      organization_id: request.organization_id,
      resource_type: "agent_token",
      resource_id: token.id,
      metadata: %{
        agent_type: AgentType.to_string(token.agent_type),
        task_id: TaskId.to_string(token.task_id),
        task_description: token.task_description,
        delegation_depth: token.delegation_chain.depth,
        delegator_user_id: token.delegator_user_id,
        scopes: token.scopes,
        expires_in: token.expires_in,
        reason: token.reason
      }
    })

    :ok
  end
end
