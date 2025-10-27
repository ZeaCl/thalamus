defmodule Thalamus.Application.Ports.OrganizationRepository do
  @moduledoc """
  Repository port (interface) for Organization entity persistence.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for organization data access
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.Domain.ValueObjects.{OrganizationId, UserId}

  @callback find_by_id(OrganizationId.t()) ::
              {:ok, Organization.t()} | {:error, :not_found}

  @callback find_by_member(UserId.t()) ::
              {:ok, [Organization.t()]} | {:error, term()}

  @callback save(Organization.t()) :: {:ok, Organization.t()} | {:error, term()}

  @callback delete(OrganizationId.t()) :: :ok | {:error, term()}

  @callback list(keyword()) :: {:ok, [Organization.t()]} | {:error, term()}

  @callback count() :: {:ok, non_neg_integer()} | {:error, term()}
end
