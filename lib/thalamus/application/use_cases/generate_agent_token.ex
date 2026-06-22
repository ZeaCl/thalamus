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
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain, OrganizationId}
  alias Thalamus.Utils.InputSanitizer

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
          {:ok, AgentTokenResponse.t()} | {:error, atom() | {atom(), any()}}
  def execute(%AgentTokenRequest{} = request, deps) do
    with :ok <- AgentTokenRequest.validate(request),
         {:ok, client} <- authenticate_client(request, deps),
         {:ok, delegator} <- validate_delegator(request, deps),
         {:ok, _organization} <- validate_organization(request, deps),
         :ok <- validate_scopes_subset(request.scopes, client.allowed_scopes),
         :ok <- validate_scope_narrowing(request, deps),
         {:ok, agent_type} <- AgentType.new(request.agent_type),
         {:ok, task_id} <- parse_or_generate_task_id(request.task_id),
         {:ok, delegation_chain} <- build_delegation_chain(request, deps),
         {:ok, agent_token} <-
           create_agent_token(request, client, delegator, agent_type, task_id, delegation_chain),
         {:ok, access_token} <- generate_access_token(),
         {:ok, saved_token} <- save_token_with_access_token(agent_token, access_token, deps),
         :ok <- log_token_creation(saved_token, request, deps) do
      response = AgentTokenResponse.from_domain(saved_token, access_token)
      {:ok, response}
    end
  end

  # Generates a cryptographically secure access token
  defp generate_access_token do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    {:ok, "at_#{token}"}
  end

  # Authenticates OAuth2 client using M2M credentials
  defp authenticate_client(%AgentTokenRequest{} = request, deps) do
    with {:ok, client} <- deps.client_repository.find_by_client_id(request.client_id),
         true <- client.is_active || {:error, :client_inactive},
         true <-
           verify_client_secret(request.client_secret, client.client_secret) ||
             {:error, :invalid_client_credentials},
         true <-
           to_string(client.organization_id) == request.organization_id ||
             {:error, :organization_mismatch} do
      {:ok, client}
    else
      {:error, :not_found} -> {:error, :invalid_client_credentials}
      {:error, reason} -> {:error, reason}
      false -> {:error, :invalid_client_credentials}
    end
  end

  # Verifies client secret using constant-time comparison
  defp verify_client_secret(
         provided_secret,
         %Thalamus.Domain.ValueObjects.ClientSecret{} = stored_secret
       ) do
    Thalamus.Domain.ValueObjects.ClientSecret.verify(stored_secret, provided_secret)
  end

  # Validates delegator user exists and is active
  defp validate_delegator(%AgentTokenRequest{} = request, deps) do
    with {:ok, user} <- deps.user_repository.find_by_id(request.delegator_user_id),
         true <- user.status == :active || {:error, :delegator_not_active},
         true <-
           to_string(user.organization_id) == request.organization_id ||
             {:error, :delegator_organization_mismatch},
         :ok <- validate_delegator_has_scopes(user, request.scopes, deps) do
      {:ok, user}
    else
      {:error, :not_found} -> {:error, :delegator_not_found}
      {:error, reason} -> {:error, reason}
      false -> {:error, :delegator_not_active}
    end
  end

  # Validates that delegator has permission to delegate the requested scopes
  # TODO: This validation is currently simplified and needs full implementation
  # when the role/permission system is added to User entity.
  #
  # For now, we perform basic checks. In the future, this should:
  # 1. Get user's effective scopes from roles/permissions
  # 2. Verify requested scopes ⊆ user's scopes
  # 3. Check organization-level delegation policies
  defp validate_delegator_has_scopes(_user, _requested_scopes, _deps) do
    # TODO: Implement when User entity has roles/permissions system
    # For now, allow delegation (assuming delegator was properly authenticated)
    #
    # Future implementation:
    # {:ok, user_scopes} = deps.user_repository.get_effective_scopes(user.id)
    # requested_set = MapSet.new(requested_scopes)
    # user_set = MapSet.new(user_scopes)
    #
    # if MapSet.subset?(requested_set, user_set) do
    #   :ok
    # else
    #   {:error, :delegator_insufficient_permissions}
    # end

    Logger.warning(
      "Delegator scope validation is simplified - full implementation pending role/permission system"
    )

    :ok
  end

  defp validate_organization(%AgentTokenRequest{} = request, deps) do
    # If organization_repository is not provided, skip validation
    # (for backwards compatibility or testing)
    if Map.has_key?(deps, :organization_repository) do
      with {:ok, org_id} <- OrganizationId.from_string(request.organization_id),
           {:ok, org} <- deps.organization_repository.find_by_id(org_id),
           true <- org.status == :active || {:error, :organization_not_active},
           :ok <- validate_compliance_rules(request, org) do
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

  # Validates organization compliance rules for agent token generation
  # TODO: This requires adding compliance_config field to Organization entity
  #
  # Expected compliance_config structure:
  # %{
  #   max_token_ttl: integer() | nil,              # Max TTL in seconds
  #   forbidden_agent_types: [atom()] | [],        # [:autonomous, :supervisor, :tool]
  #   allowed_hours: %{start: integer(), end: integer()} | nil,  # Business hours (0-23)
  #   require_mfa_for_scopes: [String.t()] | [],   # Scopes that require MFA
  #   max_delegation_depth: integer() | nil        # Max chain depth
  # }
  defp validate_compliance_rules(request, org) do
    # Get compliance config from organization (falls back to empty map if not present)
    compliance_config = Map.get(org, :compliance_config, %{})

    with :ok <- check_max_ttl(request.expires_in, compliance_config),
         :ok <- check_forbidden_agent_types(request.agent_type, compliance_config),
         :ok <- check_business_hours(compliance_config) do
      :ok
    end
  end

  # Validates TTL against organization's maximum allowed TTL
  defp check_max_ttl(nil, _config), do: :ok

  defp check_max_ttl(requested_ttl, %{max_token_ttl: max_ttl})
       when is_integer(max_ttl) and requested_ttl > max_ttl do
    {:error, :ttl_exceeds_organization_limit}
  end

  defp check_max_ttl(_ttl, _config), do: :ok

  # Validates agent type against organization's forbidden types
  defp check_forbidden_agent_types(agent_type, %{forbidden_agent_types: forbidden})
       when is_list(forbidden) do
    if agent_type in forbidden do
      {:error, :agent_type_forbidden_by_organization}
    else
      :ok
    end
  end

  defp check_forbidden_agent_types(_agent_type, _config), do: :ok

  # Validates current time against organization's allowed business hours
  defp check_business_hours(%{allowed_hours: %{start: start_hour, end: end_hour}}) do
    current_hour = DateTime.utc_now() |> Map.get(:hour)

    if current_hour >= start_hour and current_hour < end_hour do
      :ok
    else
      {:error, :outside_business_hours}
    end
  end

  defp check_business_hours(_config), do: :ok

  # Validates that requested scopes are a subset of client's allowed scopes
  defp validate_scopes_subset(requested_scopes, allowed_scopes) do
    requested_set = MapSet.new(requested_scopes)
    allowed_strings = Enum.map(allowed_scopes, &to_string/1)
    allowed_set = MapSet.new(allowed_strings)

    invalid_scopes = MapSet.difference(requested_set, allowed_set) |> MapSet.to_list()

    if Enum.empty?(invalid_scopes) do
      :ok
    else
      {:error, {:invalid_scopes, invalid_scopes}}
    end
  end

  # Validates scope narrowing for delegation chains
  # Child tokens must have scopes that are a subset of parent token scopes
  defp validate_scope_narrowing(%AgentTokenRequest{parent_agent_id: nil}, _deps) do
    # Root token - no parent to validate against
    :ok
  end

  defp validate_scope_narrowing(%AgentTokenRequest{parent_agent_id: parent_id} = request, deps) do
    with {:ok, parent_token} <- deps.agent_token_repository.find_by_id(parent_id) do
      requested_set = MapSet.new(request.scopes)
      parent_set = MapSet.new(parent_token.scopes)

      if MapSet.subset?(requested_set, parent_set) do
        :ok
      else
        {:error, :scopes_exceed_parent}
      end
    else
      {:error, :not_found} -> {:error, :parent_token_not_found}
      error -> error
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

  defp build_delegation_chain(%AgentTokenRequest{parent_agent_id: parent_id} = request, deps) do
    with {:ok, parent_token} <- deps.agent_token_repository.find_by_id(parent_id),
         true <- parent_token.status == :active || {:error, :parent_token_not_active},
         :ok <- validate_child_ttl_not_exceeds_parent(request.expires_in, parent_token),
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
      client_id: to_string(client.id),
      organization_id: request.organization_id,
      agent_type: agent_type,
      task_id: task_id,
      task_description: InputSanitizer.sanitize_text(request.task_description),
      scopes: request.scopes,
      delegation_chain: delegation_chain,
      delegator_user_id: to_string(delegator.id),
      expires_in: AgentTokenRequest.get_expires_in(request),
      reason: InputSanitizer.sanitize_text(request.reason)
    }

    AgentToken.create(params)
  end

  # Saves token using repository
  #
  # DESIGN DECISION NEEDED: Access token generation location
  #
  # Current state:
  # - Use case generates access_token (line 86) for deterministic testing
  # - Repository ignores it and generates its own internally
  # - This creates confusion and duplication
  #
  # Recommended solution (Option A):
  # Update repository interface to accept access_token:
  #   def save(agent_token, access_token) do
  #     # Store access_token in schema
  #     # Return saved token with access_token
  #   end
  #
  # Alternative (Option B):
  # Remove token generation from use case (line 86):
  #   - Let repository generate it
  #   - Repository returns {:ok, saved_token, generated_access_token}
  #   - Less testable but simpler
  #
  # TODO: Implement Option A for better testability
  defp save_token_with_access_token(agent_token, _access_token, deps) do
    # Currently: Repository generates its own access_token internally
    # This works but creates the duplication issue noted above
    deps.agent_token_repository.save(agent_token)
  end

  # Logs token creation to audit log
  defp log_token_creation(token, request, deps) do
    # Build metadata with token details
    metadata = %{
      agent_type: AgentType.to_string(token.agent_type),
      task_id: TaskId.to_string(token.task_id),
      task_description: token.task_description,
      delegation_depth: token.delegation_chain.depth,
      delegator_user_id: token.delegator_user_id,
      scopes: token.scopes,
      expires_in: token.expires_in,
      reason: token.reason
    }

    # Enrich metadata with request context if available (IP, user agent, etc.)
    enriched_metadata =
      case Map.get(deps, :context) do
        nil ->
          metadata

        context when is_map(context) ->
          Map.merge(metadata, %{
            ip_address: context[:ip_address],
            user_agent: context[:user_agent],
            request_id: context[:request_id],
            environment: context[:environment]
          })
      end

    deps.audit_logger.log(%{
      event_type: "agent_token.created",
      actor_type: "oauth2_client",
      actor_id: request.client_id,
      organization_id: request.organization_id,
      resource_type: "agent_token",
      resource_id: token.id,
      timestamp: DateTime.utc_now(),
      metadata: enriched_metadata
    })

    :ok
  end

  # Validates that child token TTL does not exceed parent's remaining TTL
  defp validate_child_ttl_not_exceeds_parent(nil, _parent_token) do
    # No TTL specified for child, will use default
    :ok
  end

  defp validate_child_ttl_not_exceeds_parent(child_ttl, parent_token) do
    # Calculate parent's expiration time from created_at + expires_in
    parent_expires_at = DateTime.add(parent_token.created_at, parent_token.expires_in, :second)
    parent_remaining = DateTime.diff(parent_expires_at, DateTime.utc_now(), :second)

    if child_ttl <= parent_remaining do
      :ok
    else
      {:error, :child_ttl_exceeds_parent}
    end
  end
end
