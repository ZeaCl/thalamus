defmodule Thalamus.Application.Ports.AdminApiKeyRepository do
  @moduledoc """
  Port (interface) for AdminApiKey repository operations.

  This behaviour defines the contract that any AdminApiKey repository
  implementation must fulfill. Implementations are in the Infrastructure layer.

  SOLID Principles Applied:
  - Dependency Inversion: Application layer defines the interface, Infrastructure implements it
  - Interface Segregation: Focused interface for AdminApiKey operations only
  """

  alias Thalamus.Domain.Entities.AdminApiKey

  @doc """
  Finds an Admin API Key by its ID.

  Returns `{:ok, admin_api_key}` if found, `{:error, :not_found}` otherwise.
  """
  @callback find_by_id(id :: String.t()) ::
              {:ok, AdminApiKey.t()} | {:error, :not_found}

  @doc """
  Finds an Admin API Key by its prefix (first 12 characters).

  The prefix is used for efficient lookup since the full key is hashed.

  Returns `{:ok, admin_api_key}` if found, `{:error, :not_found}` otherwise.
  """
  @callback find_by_prefix(key_prefix :: String.t()) ::
              {:ok, AdminApiKey.t()} | {:error, :not_found}

  @doc """
  Saves (creates or updates) an Admin API Key.

  If the key has an ID and exists in the database, it will be updated.
  Otherwise, a new key will be created.

  Returns `{:ok, admin_api_key}` on success, `{:error, changeset}` on failure.
  """
  @callback save(admin_api_key :: AdminApiKey.t()) ::
              {:ok, AdminApiKey.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Deletes an Admin API Key.

  Returns `:ok` on success, `{:error, :not_found}` if the key doesn't exist.
  """
  @callback delete(id :: String.t()) :: :ok | {:error, :not_found}

  @doc """
  Lists all Admin API Keys with optional filters.

  Supported filters:
  - `:is_active` - boolean
  - `:created_by_user_id` - string
  - `:scopes` - list of strings (returns keys that have ANY of these scopes)

  Returns `{:ok, [admin_api_key]}`.
  """
  @callback list(filters :: map()) :: {:ok, [AdminApiKey.t()]}

  @doc """
  Lists all active (non-expired, is_active=true) Admin API Keys.

  Returns `{:ok, [admin_api_key]}`.
  """
  @callback list_active() :: {:ok, [AdminApiKey.t()]}
end
