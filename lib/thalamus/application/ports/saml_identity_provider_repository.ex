defmodule Thalamus.Application.Ports.SamlIdentityProviderRepository do
  @moduledoc """
  Repository port (interface) for SAML Identity Provider persistence.

  SOLID:
  - Interface Segregation: Focused interface for SAML IdP data access
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.Entities.SamlIdentityProvider
  alias Thalamus.Domain.ValueObjects.OrganizationId

  @doc """
  Finds a SAML IdP configuration by its parent organization ID.

  Returns {:ok, SamlIdentityProvider.t()} or {:error, :not_found}.
  """
  @callback find_by_organization_id(OrganizationId.t()) ::
              {:ok, SamlIdentityProvider.t()} | {:error, :not_found}

  @doc """
  Finds an enabled SAML IdP by an email domain.

  Used during login to detect if a user's email domain matches
  a configured SAML IdP. Returns the first match.

  Returns {:ok, SamlIdentityProvider.t()} or {:error, :not_found}.
  """
  @callback find_by_email_domain(String.t()) ::
              {:ok, SamlIdentityProvider.t()} | {:error, :not_found}

  @doc """
  Saves a SAML IdP configuration (insert or update).
  """
  @callback save(SamlIdentityProvider.t()) ::
              {:ok, SamlIdentityProvider.t()} | {:error, term()}

  @doc """
  Deletes the SAML IdP configuration for an organization.
  """
  @callback delete(OrganizationId.t()) :: :ok | {:error, term()}
end
