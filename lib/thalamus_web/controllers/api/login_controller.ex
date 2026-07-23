defmodule ThalamusWeb.API.LoginController do
  use ThalamusWeb, :controller

  alias Thalamus.Application.DTOs.AuthenticationRequest
  alias Thalamus.Application.UseCases.AuthenticateUser
  alias Thalamus.DependencyBuilder
  alias Thalamus.Infrastructure.JwtSigner
  alias Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository
  alias Thalamus.Domain.ValueObjects.OrganizationId

  @api_login_client_id "thalamus_api"

  @doc """
  POST /api/public/login

  Authenticates a user with email + password and returns a signed JWT
  with domain_roles populated from user_domain_roles.

  Uses the standard architecture: Controller → AuthenticateUser → JwtSigner

  ## Request Body (JSON)
  {
    "email": "user@example.com",
    "password": "SecurePassword123!"
  }

  ## Response (200 OK)
  {
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "user": { "id": "...", "email": "...", "name": "...", "verified": true },
    "organization": { "id": "...", "name": "...", "slug": "..." }
  }
  """
  def create(conn, params) do
    email = params["email"] || ""
    password = params["password"] || ""

    if email == "" or password == "" do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "missing_parameter", error_description: "Email and password are required"})
    else
      deps = DependencyBuilder.build_for_web(conn)

      case AuthenticationRequest.new(%{email: email, password: password}) do
        {:ok, auth_request} ->
          handle_auth(conn, auth_request, deps)

        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: to_string(reason), error_description: "Invalid request"})
      end
    end
  end

  # ── Auth via AuthenticateUser use case ────────────────────────

  defp handle_auth(conn, auth_request, deps) do
    case AuthenticateUser.execute(auth_request, deps) do
      {:ok, %{authenticated: true} = auth_response} ->
        handle_authenticated(conn, auth_response)

      {:ok, %{mfa_required: true}} ->
        conn
        |> put_status(:ok)
        |> json(%{mfa_required: true, message: "MFA verification required"})

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: error_code(reason), error_description: error_description(reason)})
    end
  end

  defp handle_authenticated(conn, auth_response) do
    access_token = build_access_jwt(auth_response)
    refresh_token = build_refresh_jwt(auth_response)
    organization = fetch_organization(auth_response.organization_id)

    conn
    |> put_status(:ok)
    |> json(%{
      access_token: access_token,
      refresh_token: refresh_token,
      token_type: "Bearer",
      expires_in: 3600,
      user: %{
        id: auth_response.user_id,
        email: auth_response.email,
        name: auth_response.name,
        verified: auth_response.email_verified
      },
      organization: organization
    })
  end

  # ── JWT via JwtSigner (RS256, includes domain_roles) ──────────

  # Note: organization_id is intentionally not included as a top-level claim.
  # The OAuth2 token flow (GenerateTokens → JwtSigner) provides org context
  # inside domain_roles[].org_id, which is the canonical source. The previous
  # manual JWT had it top-level but consumers should use domain_roles.
  defp build_access_jwt(auth_response) do
    JwtSigner.sign_access_token(%{
      user_id: auth_response.user_id,
      client_id: @api_login_client_id,
      scope: "openid profile email",
      expires_in: 3600,
      aud: "zea",
      sub: auth_response.user_id,
      name: auth_response.name,
      email: auth_response.email,
      is_agent: auth_response.is_agent
    })
  end

  # ── Refresh token ─────────────────────────────────────────

  defp build_refresh_jwt(auth_response) do
    JwtSigner.sign_refresh_token(%{
      user_id: auth_response.user_id,
      aud: "zea",
      expires_in: 2_592_000
    })
  end

  # ── Organization lookup ───────────────────────────────────

  defp fetch_organization(nil), do: nil

  defp fetch_organization(org_id_string) do
    case OrganizationId.from_string(org_id_string) do
      {:ok, org_id} ->
        case PostgreSQLOrganizationRepository.find_by_id(org_id) do
          {:ok, org} ->
            %{
              id: OrganizationId.to_string(org.id),
              name: org.name,
              slug: generate_slug(org.name)
            }

          {:error, _} ->
            nil
        end

      {:error, _} ->
        nil
    end
  end

  defp generate_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp error_code(:invalid_credentials), do: "invalid_credentials"
  defp error_code(:account_locked), do: "account_locked"
  defp error_code(:account_suspended), do: "account_suspended"
  defp error_code(:account_not_verified), do: "account_not_verified"
  defp error_code(reason), do: to_string(reason)

  defp error_description(:invalid_credentials), do: "Invalid email or password"

  defp error_description(:account_locked),
    do: "Account is temporarily locked due to too many failed attempts"

  defp error_description(:account_suspended), do: "Account has been suspended"
  defp error_description(:account_not_verified), do: "Account email has not been verified"
  defp error_description(_), do: "Authentication failed"
end
