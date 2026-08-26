defmodule Thalamus.Application.Ports.EnvironmentRepository do
  @moduledoc """
  Port for Environment entity persistence operations.

  SOLID Principles:
  - Interface Segregation: Focused interface for environment data access
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.Entities.Environment

  @callback create(attrs :: map()) :: {:ok, Environment.t()} | {:error, term()}
  @callback save(environment :: Environment.t()) :: {:ok, Environment.t()} | {:error, term()}
  @callback get(id :: String.t()) :: {:ok, Environment.t()} | {:error, :not_found}
  @callback get_by_slug(org_id :: String.t(), slug :: String.t()) ::
              {:ok, Environment.t()} | {:error, :not_found}
  @callback get_default(org_id :: String.t()) ::
              {:ok, Environment.t()} | {:error, :not_found}
  @callback list_by_organization(org_id :: String.t(), filters :: map() | keyword()) ::
              {:ok, [Environment.t()]} | {:error, term()}
  @callback set_default(org_id :: String.t(), environment_id :: String.t()) ::
              {:ok, Environment.t()} | {:error, term()}
  @callback delete(id :: String.t()) :: :ok | {:error, term()}
  @callback archive(id :: String.t()) :: {:ok, Environment.t()} | {:error, term()}
end
