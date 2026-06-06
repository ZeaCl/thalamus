defmodule ThalamusWeb.SamlController do
  @moduledoc """
  Controller for SAML SSO authentication flow.

  Handles:
  - GET  /auth/saml/init      — Initiate SP-initiated SAML flow
  - POST /auth/saml/acs       — Assertion Consumer Service callback
  - GET  /auth/saml/metadata  — SP metadata XML for IdP configuration

  SOLID: Single Responsibility — only handles SAML HTTP requests.
  """

  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.AuthenticateUserViaSaml
  alias Thalamus.Domain.ValueObjects.{OrganizationId}

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLSamlIdentityProviderRepository
  }

  alias Thalamus.Infrastructure.Adapters.{
    SamlyAssertionValidator,
    AuditLoggerImpl
  }

  require Logger

  @doc """
  GET /auth/saml/init?email=user@contoso.com

  Detects the user's organization by email domain and initiates
  the SAML SSO flow by redirecting to the configured IdP.
  """
  def init(conn, params) do
    email = Map.get(params, "email", "")

    case extract_domain(email) do
      "" ->
        Logger.warning("SAML init called without valid email domain")
        redirect(conn, to: "/login")

      domain ->
        case PostgreSQLSamlIdentityProviderRepository.find_by_email_domain(domain) do
          {:ok, idp_config} ->
            relay_state = OrganizationId.to_string(idp_config.organization_id)

            case SamlyAssertionValidator.build_authn_request(idp_config, relay_state) do
              {:ok, redirect_url} ->
                Logger.info("SAML redirect to IdP: #{idp_config.name}",
                  organization_id: relay_state
                )

                conn
                |> redirect(external: redirect_url)

              {:error, reason} ->
                Logger.error("Failed to build SAML authn request: #{inspect(reason)}")
                redirect_with_error(conn, "SSO configuration error")
            end

          {:error, :not_found} ->
            redirect(conn, to: "/login?email=#{URI.encode_www_form(email)}")

          {:error, reason} ->
            Logger.error("SAML repo error: #{inspect(reason)}")
            redirect_with_error(conn, "SSO service unavailable")
        end
    end
  end

  @doc """
  POST /auth/saml/acs

  Receives the SAMLResponse from the IdP after successful authentication.
  Validates the assertion, finds/creates the user, and establishes session.
  """
  def acs(conn, params) do
    saml_response = Map.get(params, "SAMLResponse", "")
    relay_state = Map.get(params, "RelayState", "")

    with {:ok, org_id} <- parse_org_id(relay_state),
         {:ok, auth_response} <-
           AuthenticateUserViaSaml.execute(
             saml_response,
             org_id,
             saml_deps()
           ) do
      user_uuid = auth_response.user_id

      authorization_request = get_session(conn, :authorization_request)

      Logger.info("SAML login successful",
        user_id: user_uuid
      )

      conn
      |> put_flash(:info, "Signed in with SSO")
      |> put_session(:user_id, user_uuid)
      |> delete_session(:authorization_request)
      |> redirect_after_login(authorization_request)
    else
      {:error, :saml_user_not_found} ->
        Logger.warning("SAML login: user not found and JIT disabled",
          organization_id: relay_state
        )

        conn
        |> put_flash(:error, "Account not found. Please contact your administrator.")
        |> redirect(to: "/login")

      {:error, reason} ->
        Logger.error("SAML login failed: #{inspect(reason)}",
          organization_id: relay_state
        )

        conn
        |> put_flash(:error, "SSO authentication failed. Please try again.")
        |> redirect(to: "/login")
    end
  end

  @doc """
  GET /auth/saml/metadata/:org_id

  Returns the SP metadata XML for a specific organization.
  The client uses this XML to configure their IdP (Azure AD, Okta, etc.).
  """
  def metadata(conn, %{"id" => id}) do
    result =
      try do
        with {:ok, org_id} <- OrganizationId.from_string(id),
             {:ok, idp_config} <-
               PostgreSQLSamlIdentityProviderRepository.find_by_organization_id(org_id),
             {:ok, xml} <- SamlyAssertionValidator.build_sp_metadata(idp_config) do
          {:ok, xml}
        end
      rescue
        _ -> {:error, :not_found}
      end

    case result do
      {:ok, xml} ->
        conn
        |> put_resp_content_type("application/samlmetadata+xml")
        |> send_resp(200, xml)

      _error ->
        send_resp(conn, 404, "Not Found")
    end
  end

  # ─── Private ────────────────────────────────────────────────

  defp extract_domain(email) when is_binary(email) do
    case String.split(email, "@") do
      [_, domain] -> String.downcase(domain)
      _ -> ""
    end
  end

  defp extract_domain(_), do: ""

  defp parse_org_id(relay_state) do
    case relay_state do
      "" -> {:error, :missing_relay_state}
      id -> OrganizationId.from_string(id)
    end
  end

  defp redirect_after_login(conn, nil) do
    return_to = get_session(conn, :return_to) || "/dashboard"
    redirect(conn, to: return_to)
  end

  defp redirect_after_login(conn, auth_request)
       when is_map(auth_request) and map_size(auth_request) > 0 do
    query = URI.encode_query(auth_request)
    redirect(conn, to: "/oauth/authorize?#{query}")
  end

  defp redirect_after_login(conn, _) do
    return_to = get_session(conn, :return_to) || "/dashboard"
    redirect(conn, to: return_to)
  end

  defp redirect_with_error(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/login")
  end

  defp saml_deps do
    %{
      user_repository: Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository,
      saml_idp_repository: PostgreSQLSamlIdentityProviderRepository,
      saml_service: SamlyAssertionValidator,
      audit_logger: AuditLoggerImpl
    }
  end
end
