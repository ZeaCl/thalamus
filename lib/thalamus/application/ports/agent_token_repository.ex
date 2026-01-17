defmodule Thalamus.Application.Ports.AgentTokenRepository do
  @moduledoc """
  Port (behaviour) defining the contract for agent token persistence.

  This interface follows the Dependency Inversion Principle:
  - Application layer defines the contract (this port)
  - Infrastructure layer provides implementations
  - Domain entities remain independent

  SOLID Principles:
  - Interface Segregation: Focused interface for agent token operations
  - Dependency Inversion: Application depends on abstraction, not concrete implementation
  """

  alias Thalamus.Domain.Entities.AgentToken

  @type save_result :: {:ok, AgentToken.t()} | {:error, Ecto.Changeset.t() | atom()}
  @type find_result :: {:ok, AgentToken.t()} | {:error, :not_found}
  @type find_many_result :: {:ok, [AgentToken.t()]} | {:error, atom()}
  @type revoke_result :: {:ok, AgentToken.t()} | {:error, :not_found | atom()}
  @type count_result :: {:ok, non_neg_integer()} | {:error, atom()}

  @doc """
  Saves an agent token to the database.

  Creates a new record if the token doesn't exist, updates if it does.
  """
  @callback save(AgentToken.t()) :: save_result()

  @doc """
  Finds an agent token by its UUID.

  Returns `{:error, :not_found}` if token doesn't exist.
  """
  @callback find_by_id(String.t()) :: find_result()

  @doc """
  Finds an agent token by its access token string.

  Returns `{:error, :not_found}` if token doesn't exist.
  """
  @callback find_by_access_token(String.t()) :: find_result()

  @doc """
  Finds all agent tokens for a given organization with pagination.

  ## Options
  - `:limit` - Maximum number of results (default: 50)
  - `:offset` - Number of results to skip (default: 0)
  - `:include_revoked` - Include revoked tokens (default: false)
  """
  @callback find_by_organization(String.t(), keyword()) :: find_many_result()

  @doc """
  Revokes an agent token by its ID.

  Sets `revoked_at` to current timestamp with optional reason.
  """
  @callback revoke(String.t(), String.t() | nil) :: revoke_result()

  @doc """
  Revokes an entire delegation chain starting from a parent token.

  Recursively revokes the parent token and all its descendants.
  Returns count of tokens revoked.
  """
  @callback revoke_delegation_chain(String.t(), String.t() | nil) :: count_result()

  @doc """
  Counts active agent tokens for an organization.

  Active = not revoked and not expired.
  """
  @callback count_active_by_organization(String.t()) :: count_result()
end
