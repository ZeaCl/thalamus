defmodule Thalamus.Application.UseCases.GenerateAgentToken do
  @moduledoc """
  Use case for generating agent-specific access tokens with task-scoping and delegation tracking.

  SOLID Principles:
  - Single Responsibility: Only handles agent token generation
  - Dependency Inversion: Depends on ports (repositories), not implementations
  - Open/Closed: Extensible without modifying existing OAuth2 token generation

  ## Features

  - Task-scoped tokens with operation limits
  - Delegation chain tracking
  - Compliance-ready audit trails
  - Automatic token revocation on task completion

  ## Security Considerations

  - Validates delegator exists and is active
  - Enforces task_scopes as strict subset of client.allowed_scopes
  - Maximum TTL of 3600 seconds (1 hour) for agent tokens
  - Logs all agent token creations with full context
  """

  require Logger

  alias Thalamus.Application.DTOs.{AgentTokenRequest, AgentTokenResponse}
  alias Thalamus.Application.UseCases.GetEffectiveScopes

  alias Thalamus.Domain.ValueObjects.{
    AgentType,
    TaskId,
    DelegationChain,
    UserId
  }

  @type deps :: %{
          client_repository: module(),
          user_repository: module(),
          token_repository: module(),
          audit_logger: module(),
          role_repository: module(),
          cache_service: module()
        }

  # 1 hour max for agent tokens
  @max_ttl 3600
  # 15 minutes default
  @default_ttl 900

  @doc """
  Executes agent token generation.

  ## Flow

  1. Validate request structure
  2. Authenticate OAuth2 client
  3. Validate delegator exists and is active
  4. Validate task_scopes are subset of client.allowed_scopes
  5. Generate agent token with metadata
  6. Store token in repository
  7. Log audit event
  8. Return token response

  ## Examples

      iex> request = %AgentTokenRequest{
      ...>   client_id: "client_abc",
      ...>   client_secret: "secret",
      ...>   delegated_by_user_id: "user_123",
      ...>   agent_type: "autonomous",
      ...>   task_scopes: ["api:read", "data:read"]
      ...> }
      iex> GenerateAgentToken.execute(request, deps)
      {:ok, %AgentTokenResponse{access_token: "at_...", ...}}
  """
  @spec execute(AgentTokenRequest.t(), deps()) :: {:ok, AgentTokenResponse.t()} | {:error, atom()}
  def execute(%AgentTokenRequest{} = request, deps) do
    start_time = System.monotonic_time()

    result =
      with :ok <- AgentTokenRequest.validate(request),
           {:ok, client} <- authenticate_client(request, deps),
           {:ok, delegator} <- validate_delegator(request, deps),
           {:ok, agent_type} <- parse_agent_type(request),
           {:ok, task_id} <- parse_task_id(request),
           {:ok, task_scopes} <- validate_task_scopes(request, client),
           :ok <- validate_delegator_has_scopes(delegator, task_scopes, deps),
           {:ok, delegation_chain} <- build_delegation_chain(delegator),
           {:ok, token_data} <-
             build_token_data(
               request,
               client,
               delegator,
               agent_type,
               task_id,
               task_scopes,
               delegation_chain
             ),
           store_result <- deps.token_repository.store(token_data),
           :ok <- normalize_store_result(store_result),
           :ok <- log_agent_token_creation(token_data, deps) do
        response = %AgentTokenResponse{
          access_token: token_data.token,
          token_type: "Bearer",
          expires_in: token_data.expires_in,
          scope: Enum.join(task_scopes, " "),
          agent_type: request.agent_type,
          task_id: request.task_id,
          max_operations: request.max_operations,
          expires_on_completion: request.expires_on_completion
        }

        # Emit telemetry events (Epic 7)
        emit_agent_token_telemetry(token_data, delegation_chain, start_time)

        {:ok, response}
      end

    result
  end

  # --- Private Functions ---

  defp authenticate_client(%{client_id: client_id, client_secret: client_secret}, deps) do
    with {:ok, client} <- deps.client_repository.find_by_client_id(client_id),
         :ok <- verify_client_secret(client, client_secret),
         :ok <- check_client_active(client) do
      {:ok, client}
    else
      {:error, :not_found} -> {:error, :invalid_client}
      error -> error
    end
  end

  defp verify_client_secret(client, provided_secret) do
    # Extract hash - handle both Value Object and plain string
    secret_hash =
      case client.client_secret do
        %Thalamus.Domain.ValueObjects.ClientSecret{} = secret ->
          Thalamus.Domain.ValueObjects.ClientSecret.to_string(secret)

        hash when is_binary(hash) ->
          hash

        _ ->
          nil
      end

    if secret_hash && Bcrypt.verify_pass(provided_secret, secret_hash) do
      :ok
    else
      {:error, :invalid_client}
    end
  end

  defp check_client_active(%{is_active: true}), do: :ok
  defp check_client_active(_), do: {:error, :client_inactive}

  defp validate_delegator(%{delegated_by_user_id: user_id}, deps) do
    case deps.user_repository.find_by_id(user_id) do
      {:ok, user} ->
        # Handle both User entity (has :status) and mock structs (have :is_active)
        is_active =
          case user do
            %{status: :active} -> true
            %{is_active: true} -> true
            _ -> false
          end

        if is_active do
          {:ok, user}
        else
          {:error, :delegator_inactive}
        end

      {:error, :not_found} ->
        {:error, :delegator_not_found}
    end
  end

  defp parse_agent_type(%{agent_type: type}) do
    AgentType.new(type)
  end

  defp parse_task_id(%{task_id: nil}), do: {:ok, nil}

  defp parse_task_id(%{task_id: task_id}) do
    TaskId.new(task_id)
  end

  defp validate_task_scopes(%{task_scopes: []}, _client) do
    {:error, :empty_task_scopes}
  end

  defp validate_task_scopes(%{task_scopes: task_scopes}, client) do
    # Convert client allowed_scopes to strings for comparison
    allowed_scope_strings =
      Enum.map(client.allowed_scopes, fn scope ->
        case scope do
          %{value: value} -> value
          scope when is_binary(scope) -> scope
        end
      end)

    # Validate each task scope
    case validate_scopes_subset(task_scopes, allowed_scope_strings) do
      :ok -> {:ok, task_scopes}
      {:error, invalid_scopes} -> {:error, {:invalid_task_scopes, invalid_scopes}}
    end
  end

  defp validate_scopes_subset(task_scopes, allowed_scopes) do
    invalid = Enum.reject(task_scopes, fn scope -> scope in allowed_scopes end)

    if Enum.empty?(invalid) do
      :ok
    else
      {:error, invalid}
    end
  end

  # RBAC: Validate that delegator has permission to delegate the requested scopes
  defp validate_delegator_has_scopes(delegator, requested_scopes, deps) do
    # Extract raw UUID from UserId value object (remove "user_" prefix)
    user_uuid = extract_user_uuid(delegator.id)

    # Get user's effective scopes (from assigned roles)
    case GetEffectiveScopes.execute(user_uuid, deps) do
      {:ok, []} ->
        # User has no roles assigned - allow delegation (backward compatibility)
        # This ensures existing users without roles continue to work
        Logger.info(
          "User #{delegator.id} has no roles assigned, allowing delegation (backward compatible)"
        )

        :ok

      {:ok, user_scopes} ->
        # User has roles - enforce scope validation
        requested_set = MapSet.new(requested_scopes)
        user_set = MapSet.new(user_scopes)

        if MapSet.subset?(requested_set, user_set) do
          :ok
        else
          Logger.warning(
            "User #{delegator.id} attempted to delegate scopes beyond their permissions. " <>
              "Requested: #{inspect(requested_scopes)}, User scopes: #{inspect(user_scopes)}"
          )

          {:error, :delegator_insufficient_permissions}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_delegation_chain(delegator) do
    # Handle both UserId Value Object and plain string
    user_id_string =
      case delegator.id do
        %Thalamus.Domain.ValueObjects.UserId{} = user_id ->
          Thalamus.Domain.ValueObjects.UserId.to_string(user_id)

        id when is_binary(id) ->
          id

        _ ->
          nil
      end

    DelegationChain.from_delegator(user_id_string)
  end

  defp build_token_data(
         request,
         client,
         delegator,
         agent_type,
         task_id,
         task_scopes,
         delegation_chain
       ) do
    token = generate_access_token()
    ttl = calculate_ttl(request.ttl)
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :second)

    token_data = %{
      # Standard OAuth2 fields
      token: token,
      type: :access_token,
      scopes: task_scopes,
      expires_at: expires_at,
      expires_in: ttl,

      # Relationships
      # Agent tokens are not tied to a user
      user_id: nil,
      client_id: client.id,
      organization_id: client.organization_id,

      # Agent-specific fields
      agent_type: AgentType.to_string(agent_type),
      delegated_by_user_id: delegator.id,
      delegation_chain: extract_delegation_chain_ids(delegation_chain),

      # Task-scoping fields
      task_id: task_id && TaskId.to_string(task_id),
      task_type: request.task_type,
      task_scopes: task_scopes,
      max_operations: request.max_operations,
      operations_count: 0,
      expires_on_completion: request.expires_on_completion,

      # Attestation fields
      intent_description: request.intent_description,
      orchestrator_id: request.orchestrator_id,
      environment: Application.get_env(:thalamus, :environment, "development"),

      # Metadata
      metadata: %{
        created_via: "agent_token_endpoint",
        api_version: "v1",
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    {:ok, token_data}
  end

  defp generate_access_token do
    "at_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))
  end

  defp calculate_ttl(nil), do: @default_ttl
  defp calculate_ttl(ttl) when ttl > @max_ttl, do: @max_ttl
  defp calculate_ttl(ttl), do: ttl

  defp extract_delegation_chain_ids(%DelegationChain{chain: chain}) do
    Enum.map(chain, fn user_id ->
      case user_id do
        %{value: uuid} -> uuid
        uuid when is_binary(uuid) -> uuid
      end
    end)
  end

  # Normalize store result to handle both :ok and {:ok, _} returns
  # This supports both the port spec (:ok) and test mocks ({:ok, token_data})
  defp normalize_store_result(:ok), do: :ok
  defp normalize_store_result({:ok, _}), do: :ok
  defp normalize_store_result(error), do: error

  defp log_agent_token_creation(token, deps) do
    deps.audit_logger.log(%{
      event_type: "agent_token_generated",
      user_id: token.delegated_by_user_id,
      organization_id: token.organization_id,
      client_id: token.client_id,
      metadata: %{
        agent_type: token.agent_type,
        task_id: token.task_id,
        task_scopes: token.task_scopes,
        max_operations: token.max_operations,
        intent_description: token.intent_description,
        orchestrator_id: token.orchestrator_id
      }
    })
  end

  # Emit telemetry events for observability (Epic 7)
  defp emit_agent_token_telemetry(token_data, delegation_chain, start_time) do
    end_time = System.monotonic_time()
    duration = end_time - start_time

    # Counter: agent tokens issued
    :telemetry.execute(
      [:thalamus, :agent_tokens, :issued],
      %{count: 1},
      %{
        agent_type: token_data.agent_type,
        organization_id: to_string(token_data.organization_id)
      }
    )

    # Histogram: delegation chain depth
    depth = DelegationChain.depth(delegation_chain)

    :telemetry.execute(
      [:thalamus, :agent_tokens, :delegation_depth],
      %{depth: depth},
      %{agent_type: token_data.agent_type}
    )

    # Summary: generation duration
    :telemetry.execute(
      [:thalamus, :agent_tokens, :generation_duration],
      %{duration: duration},
      %{agent_type: token_data.agent_type}
    )

    :ok
  end

  # Helper to extract raw UUID from UserId value object
  # UserId.value has format "user_xxxxx", we need just "xxxxx"
  defp extract_user_uuid(%UserId{value: value}) when is_binary(value) do
    String.replace_prefix(value, "user_", "")
  end

  defp extract_user_uuid(user_id) when is_binary(user_id) do
    # Already a raw UUID string
    String.replace_prefix(user_id, "user_", "")
  end
end
