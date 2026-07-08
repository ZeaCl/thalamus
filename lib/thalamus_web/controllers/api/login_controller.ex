defmodule ThalamusWeb.API.LoginController do
  use ThalamusWeb, :controller

  alias Thalamus.Application.DTOs.AuthenticationRequest
  alias Thalamus.Application.UseCases.AuthenticateUser
  alias Thalamus.DependencyBuilder
  alias Thalamus.Domain.ValueObjects.{UserId, Email}
  alias Thalamus.Infrastructure.JwtSigner

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
    "token_type": "Bearer",
    "expires_in": 3600,
    "user": { "id": "...", "email": "...", "name": "...", "verified": true }
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
        handle_authenticated(conn, auth_response, deps)

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

  defp handle_authenticated(conn, auth_response, deps) do
    with {:ok, uid} <- UserId.new(auth_response.user_id),
         {:ok, user} <- deps.user_repository.find_by_id(uid) do
      token = build_jwt(user)

      conn
      |> put_status(:ok)
      |> json(%{
        access_token: token,
        token_type: "Bearer",
        expires_in: 3600,
        user: %{
          id: UserId.to_string(user.id),
          email: Email.to_string(user.email),
          name: user.name,
          verified: user.email_verified
        }
      })
    end
  end

  # ── JWT via JwtSigner (RS256, includes domain_roles) ──────────

  defp build_jwt(user) do
    JwtSigner.sign_access_token(%{
      user_id: user.id,
      client_id: "thalamus_api",
      scope: "openid profile email",
      expires_in: 3600,
      aud: "zea",
      sub: UserId.to_string(user.id),
      name: user.name,
      email: Email.to_string(user.email),
      is_agent: user.is_agent
    })
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp error_code(:invalid_credentials), do: "invalid_credentials"
  defp error_code(:account_inactive), do: "account_inactive"
  defp error_code(:account_locked), do: "account_locked"
  defp error_code(:account_suspended), do: "account_suspended"
  defp error_code(:account_not_verified), do: "account_not_verified"
  defp error_code(reason), do: to_string(reason)

  defp error_description(:invalid_credentials), do: "Invalid email or password"
  defp error_description(:account_inactive), do: "Account is not active"

  defp error_description(:account_locked),
    do: "Account is temporarily locked due to too many failed attempts"

  defp error_description(:account_suspended), do: "Account has been suspended"
  defp error_description(:account_not_verified), do: "Account email has not been verified"
  defp error_description(_), do: "Authentication failed"
end
