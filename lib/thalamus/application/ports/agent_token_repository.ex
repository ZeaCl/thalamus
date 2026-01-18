defmodule Thalamus.Application.Ports.AgentTokenRepository do
  @moduledoc """
  Repository port (interface) for agent token storage and retrieval.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for agent token operations
  - Dependency Inversion: Application layer depends on this abstraction

  Per 03-tasks.md Epic 2.3 specification.
  """

  alias Thalamus.Domain.Entities.AgentToken

  @doc """
  Saves an agent token (insert or update).

  ## Parameters

  - `token` - AgentToken entity to persist

  ## Returns

  - `{:ok, AgentToken.t()}` - Saved token entity
  - `{:error, term()}` - Persistence failure
  """
  @callback save(AgentToken.t()) :: {:ok, AgentToken.t()} | {:error, term()}

  @doc """
  Finds an agent token by its unique ID.

  ## Parameters

  - `id` - Token UUID

  ## Returns

  - `{:ok, AgentToken.t()}` - Token entity
  - `{:error, :not_found}` - Token does not exist
  """
  @callback find_by_id(Ecto.UUID.t()) :: {:ok, AgentToken.t()} | {:error, :not_found}

  @doc """
  Finds an agent token by its access token value.

  ## Parameters

  - `access_token` - Access token string (e.g., "at_xxx")

  ## Returns

  - `{:ok, AgentToken.t()}` - Token entity
  - `{:error, :not_found}` - Token does not exist
  """
  @callback find_by_access_token(String.t()) :: {:ok, AgentToken.t()} | {:error, :not_found}

  @doc """
  Revokes a single agent token by its access token value.

  ## Parameters

  - `access_token` - Access token string to revoke

  ## Returns

  - `{:ok, AgentToken.t()}` - Revoked token entity
  - `{:error, :not_found}` - Token does not exist
  - `{:error, term()}` - Persistence failure
  """
  @callback revoke(String.t()) :: {:ok, AgentToken.t()} | {:error, :not_found | term()}

  @doc """
  Revokes all tokens in a delegation chain.

  When a parent token is revoked, all tokens in its delegation chain
  (tokens created by delegating from this token) must also be revoked
  for security compliance.

  ## Parameters

  - `user_id` - Root user ID in the delegation chain

  ## Returns

  - `{:ok, non_neg_integer()}` - Number of tokens revoked
  - `{:error, term()}` - Persistence failure
  """
  @callback revoke_delegation_chain(Ecto.UUID.t()) ::
              {:ok, non_neg_integer()} | {:error, term()}

  @doc """
  Finds agent tokens for an organization with optional filtering.

  ## Parameters

  - `organization_id` - Organization UUID
  - `opts` - Filter options:
    - `:agent_type` - Filter by AgentType (autonomous, supervisor, tool)
    - `:active_only` - Boolean, if true returns only non-revoked, non-expired tokens
    - `:limit` - Maximum number of results
    - `:offset` - Pagination offset

  ## Returns

  - `{:ok, [AgentToken.t()]}` - List of token entities
  - `{:error, term()}` - Query failure
  """
  @callback find_by_organization(Ecto.UUID.t(), keyword()) ::
              {:ok, [AgentToken.t()]} | {:error, term()}

  @doc """
  Cleans up expired agent tokens.

  Deletes tokens where expires_at < current time.

  ## Returns

  - `{:ok, non_neg_integer()}` - Number of tokens deleted
  - `{:error, term()}` - Deletion failure
  """
  @callback cleanup_expired() :: {:ok, non_neg_integer()} | {:error, term()}
end
