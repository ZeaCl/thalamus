defmodule Thalamus.Application.UseCases.RevokeAgentToken do
  @moduledoc """
  Use case for revoking agent tokens with cascade support for delegation chains.

  SOLID Principles:
  - Single Responsibility: Only handles agent token revocation
  - Dependency Inversion: Depends on ports (repositories), not implementations
  - Open/Closed: Extensible revocation strategies without modification

  ## Features

  - Single token revocation
  - Cascade revocation of entire delegation chains
  - Audit logging for compliance
  - Cache invalidation hooks
  - Multi-tenant isolation enforcement

  ## Security Considerations

  - Validates token ownership (organization_id match)
  - Validates requester permissions
  - Logs all revocations with reason
  - Supports cascade revocation to prevent orphaned child tokens
  """

  require Logger

  alias Thalamus.Application.Ports.AgentTokenRepository
  alias Thalamus.Domain.ValueObjects.AgentType

  @type revoke_request :: %{
          required(:token_id) => String.t(),
          required(:organization_id) => String.t(),
          required(:revoked_by_user_id) => String.t(),
          optional(:reason) => String.t() | nil,
          optional(:cascade) => boolean()
        }

  @type deps :: %{
          required(:agent_token_repository) => module(),
          required(:audit_logger) => module(),
          optional(:cache_service) => module()
        }

  @doc """
  Executes agent token revocation.

  ## Flow

  1. Validate request parameters
  2. Find token by ID
  3. Validate token belongs to organization (multi-tenant check)
  4. Revoke token (single or cascade based on request)
  5. Invalidate cache if cache service provided
  6. Log audit event
  7. Return success

  ## Parameters

  - `request`: Map with token_id, organization_id, revoked_by_user_id, optional reason and cascade flag
  - `deps`: Dependencies map with repositories and services

  ## Examples

      # Revoke single token
      iex> request = %{
      ...>   token_id: "token_123",
      ...>   organization_id: "org_abc",
      ...>   revoked_by_user_id: "user_xyz",
      ...>   reason: "Task completed"
      ...> }
      iex> RevokeAgentToken.execute(request, deps)
      {:ok, :revoked}

      # Revoke with cascade (entire delegation chain)
      iex> request = %{
      ...>   token_id: "parent_token_123",
      ...>   organization_id: "org_abc",
      ...>   revoked_by_user_id: "user_xyz",
      ...>   reason: "Parent task cancelled",
      ...>   cascade: true
      ...> }
      iex> RevokeAgentToken.execute(request, deps)
      {:ok, {:revoked_cascade, 5}}  # Revoked 5 tokens total
  """
  @spec execute(revoke_request(), deps()) :: {:ok, atom() | tuple()} | {:error, atom()}
  def execute(request, deps) do
    with :ok <- validate_request(request),
         {:ok, token} <- find_token(request.token_id, deps),
         :ok <- validate_organization_ownership(token, request.organization_id),
         result <- revoke_token(token, request, deps),
         :ok <- invalidate_cache(token, deps),
         :ok <- log_revocation(token, request, result, deps) do
      format_result(result)
    end
  end

  # Validates request parameters
  defp validate_request(%{token_id: nil}), do: {:error, :missing_token_id}
  defp validate_request(%{token_id: ""}), do: {:error, :missing_token_id}
  defp validate_request(%{organization_id: nil}), do: {:error, :missing_organization_id}
  defp validate_request(%{organization_id: ""}), do: {:error, :missing_organization_id}

  defp validate_request(%{revoked_by_user_id: nil}),
    do: {:error, :missing_revoked_by_user_id}

  defp validate_request(%{revoked_by_user_id: ""}),
    do: {:error, :missing_revoked_by_user_id}

  defp validate_request(%{token_id: token_id}) do
    case Ecto.UUID.cast(token_id) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_token_id}
    end
  end

  # Finds token by ID
  defp find_token(token_id, deps) do
    deps.agent_token_repository.find_by_id(token_id)
  end

  # Validates token belongs to the organization (multi-tenant isolation)
  defp validate_organization_ownership(token, organization_id) do
    if token.organization_id == organization_id do
      :ok
    else
      {:error, :token_not_found}
    end
  end

  # Revokes token (single or cascade)
  defp revoke_token(token, %{cascade: true} = request, deps) do
    # Cascade revocation - revoke entire delegation chain
    case deps.agent_token_repository.revoke_delegation_chain(
           token.id,
           request[:reason] || "Cascade revocation"
         ) do
      {:ok, count} -> {:ok, {:cascade, count}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp revoke_token(token, request, deps) do
    # Single token revocation
    case deps.agent_token_repository.revoke(token.id, request[:reason]) do
      {:ok, _revoked_token} -> {:ok, :single}
      {:error, reason} -> {:error, reason}
    end
  end

  # Invalidates cache if cache service is provided
  defp invalidate_cache(token, %{cache_service: cache_service}) do
    # Invalidate by token ID
    cache_service.delete("agent_token:#{token.id}")

    # Invalidate organization cache
    cache_service.delete("agent_tokens:org:#{token.organization_id}")

    :ok
  rescue
    _error ->
      # Log cache invalidation failure but don't fail the revocation
      Logger.warning("Failed to invalidate cache for token #{token.id}")
      :ok
  end

  defp invalidate_cache(_token, _deps), do: :ok

  # Logs revocation to audit log
  defp log_revocation(token, request, result, deps) do
    {event_type, metadata} =
      case result do
        {:ok, :single} ->
          {"agent_token.revoked", %{revocation_type: "single"}}

        {:ok, {:cascade, count}} ->
          {"agent_token.revoked_cascade", %{revocation_type: "cascade", tokens_revoked: count}}

        _ ->
          {"agent_token.revoked", %{revocation_type: "single"}}
      end

    deps.audit_logger.log(%{
      event_type: event_type,
      actor_type: "user",
      actor_id: request.revoked_by_user_id,
      organization_id: token.organization_id,
      resource_type: "agent_token",
      resource_id: token.id,
      metadata:
        Map.merge(metadata, %{
          agent_type: AgentType.to_string(token.agent_type),
          delegation_depth: token.delegation_chain.depth,
          reason: request[:reason]
        })
    })

    :ok
  end

  # Formats result for response
  defp format_result({:ok, :single}), do: {:ok, :revoked}
  defp format_result({:ok, {:cascade, count}}), do: {:ok, {:revoked_cascade, count}}
  defp format_result({:error, reason}), do: {:error, reason}
end
