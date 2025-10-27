defmodule Thalamus.Application.Ports.OAuth2ClientRepository do
  @moduledoc """
  Repository port (interface) for OAuth2Client entity persistence.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for OAuth2 client data access
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{ClientId, OrganizationId}

  @callback find_by_id(ClientId.t()) :: {:ok, OAuth2Client.t()} | {:error, :not_found}

  @callback find_by_client_id(String.t()) :: {:ok, OAuth2Client.t()} | {:error, :not_found}

  @callback find_by_organization(OrganizationId.t()) ::
              {:ok, [OAuth2Client.t()]} | {:error, term()}

  @callback save(OAuth2Client.t()) :: {:ok, OAuth2Client.t()} | {:error, term()}

  @callback delete(ClientId.t()) :: :ok | {:error, term()}

  @callback list(keyword()) :: {:ok, [OAuth2Client.t()]} | {:error, term()}

  @callback count_by_organization(OrganizationId.t()) ::
              {:ok, non_neg_integer()} | {:error, term()}
end
