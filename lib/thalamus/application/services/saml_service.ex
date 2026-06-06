defmodule Thalamus.Application.Services.SamlService do
  @moduledoc """
  Service behaviour (port) for SAML protocol operations.

  Defines the interface for SAML cryptographic operations:
  - Building SP metadata XML
  - Building AuthnRequests (redirect to IdP)
  - Validating SAML assertions from IdP

  Implemented by the infrastructure adapter SamlyAssertionValidator.

  SOLID:
  - Interface Segregation: Only SAML protocol operations
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.Entities.SamlIdentityProvider

  @doc """
  Generates SP metadata XML for a given IdP configuration.

  Returns {:ok, xml_string} containing the SAML SP metadata
  that the client must configure in their IdP.
  """
  @callback build_sp_metadata(SamlIdentityProvider.t()) ::
              {:ok, xml :: String.t()} | {:error, atom()}

  @doc """
  Builds a SAML AuthnRequest and returns the redirect URL.

  The relay_state parameter carries data (typically organization_id)
  that will be returned to us in the assertion callback (ACS).
  """
  @callback build_authn_request(
              idp_config :: SamlIdentityProvider.t(),
              relay_state :: String.t()
            ) :: {:ok, redirect_url :: String.t()} | {:error, atom()}

  @doc """
  Validates a SAML assertion/response from an IdP.

  Receives the raw SAMLResponse from the HTTP POST body and
  the IdP configuration (with certificate for signature validation).

  Returns {:ok, assertion_data} with at minimum:
    - :email — user's email from NameID or attributes
    - :name — user's display name (may be nil)
    - :name_id — the SAML NameID value
    - :session_index — SAML session index
  """
  @callback validate_assertion(
              saml_response :: String.t(),
              idp_config :: SamlIdentityProvider.t()
            ) :: {:ok, assertion_data :: map()} | {:error, atom()}
end
