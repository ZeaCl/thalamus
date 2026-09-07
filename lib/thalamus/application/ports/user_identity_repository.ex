defmodule Thalamus.Application.Ports.UserIdentityRepository do
  @moduledoc """
  Repository port for federated UserIdentity persistence.

  SOLID:
  - Interface Segregation: Focused interface for user identity data access
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.Entities.UserIdentity

  @doc """
  Finds a user identity by provider and external provider UID.
  """
  @callback find_by_provider_and_uid(provider :: String.t(), uid :: String.t()) ::
              {:ok, UserIdentity.t()} | {:error, :not_found}

  @doc """
  Finds all identities associated with a user ID.
  """
  @callback find_all_by_user_id(user_id :: binary()) ::
              {:ok, [UserIdentity.t()]} | {:error, term()}

  @doc """
  Finds a specific identity for a user and provider.
  """
  @callback find_by_user_and_provider(user_id :: binary(), provider :: String.t()) ::
              {:ok, UserIdentity.t()} | {:error, :not_found}

  @doc """
  Saves a UserIdentity (insert or update).
  """
  @callback save(UserIdentity.t()) ::
              {:ok, UserIdentity.t()} | {:error, term()}

  @doc """
  Deletes an identity by its ID.
  """
  @callback delete(id :: binary()) :: :ok | {:error, term()}
end
