defmodule ThalamusWeb.Plugs.AuthenticateToken do
  @moduledoc """
  Authentication Plug for API endpoints.

  Validates Bearer tokens in the Authorization header and injects
  authenticated user/client context into the connection.

  Two validation strategies, tried in order:
  1. Opaque tokens — looked up in the tokens DB table (OAuth2 flow)
  2. JWT tokens — validated via JWKS signature (public login flow)

  ## Usage

      pipeline :authenticated_api do
        plug :accepts, ["json"]
        plug ThalamusWeb.Plugs.AuthenticateToken
      end

  ## Assigns

  After successful authentication, the following are available in conn.assigns:
  - :current_user_id - The authenticated user's ID (if present)
  - :current_client_id - The OAuth2 client ID
  - :token_scope - List of granted scopes
  - :auth_context - Full authentication context map
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Thalamus.Application.UseCases.ValidateToken
  alias Thalamus.Infrastructure.JwtSigner

  # Dependencies
  @deps %{
    token_repository: Thalamus.Infrastructure.Repositories.PostgreSQLTokenRepository
  }

  @doc """
  Initialize the plug with options.

  ## Options
  - :required_scopes - List of required scopes (optional)
  - :allow_expired - Whether to allow expired tokens (default: false)
  """
  def init(opts), do: opts

  @doc """
  Call the plug to authenticate the request.

  Extracts and validates the Bearer token from the Authorization header.
  """
  def call(conn, _opts) do
    case extract_token(conn) do
      {:ok, token} ->
        validate_and_authenticate(conn, token)

      {:error, :missing_token} ->
        unauthorized(conn, "Missing authentication token")

      {:error, :invalid_format} ->
        unauthorized(conn, "Invalid authorization header format")
    end
  end

  # Private functions

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      [] ->
        {:error, :missing_token}

      [auth_header | _] ->
        parse_authorization_header(auth_header)
    end
  end

  defp parse_authorization_header("Bearer " <> token) when byte_size(token) > 0 do
    {:ok, String.trim(token)}
  end

  defp parse_authorization_header(_), do: {:error, :invalid_format}

  defp validate_and_authenticate(conn, token) do
    case ValidateToken.execute(token, @deps) do
      {:ok, %{valid: true, active: true} = result} ->
        inject_opaque_context(conn, result)

      {:ok, %{valid: false}} ->
        # Token not valid in DB — try JWT fallback only if it looks like
        # a self-contained JWT (3 segments). OAuth2 tokens use the same
        # JWT format but are stored in DB; public login tokens are not.
        # We distinguish by client_id: thalamus_api = public login JWT.
        if jwt_format?(token) and thalamus_api_jwt?(token) do
          case validate_jwt(token) do
            {:ok, claims} ->
              inject_jwt_context(conn, claims)

            {:error, _} ->
              unauthorized(conn, "Invalid or inactive token")
          end
        else
          unauthorized(conn, "Invalid or inactive token")
        end

      {:error, :invalid_token_format} ->
        unauthorized(conn, "Invalid token format")
    end
  end

  @doc false
  def jwt_format?(token) do
    JwtSigner.jwt_format?(token)
  end

  # Only fall back to JWT signature validation for tokens from the
  # public login endpoint (thalamus_api client). OAuth2 tokens are
  # also JWTs but must go through DB validation to support revocation.
  @doc false
  def thalamus_api_jwt?(token) do
    JwtSigner.thalamus_api_jwt?(token)
  end

  # ── Opaque token context injection ───────────────────────────

  defp inject_opaque_context(conn, result) do
    conn
    |> assign(:current_user_id, result.user_id)
    |> assign(:current_client_id, result.client_id)
    |> assign(:token_scope, result.scope)
    |> assign(:auth_context, result)
  end

  # ── JWT validation via JWKS (fallback) ───────────────────────

  defp validate_jwt(token) do
    case JwtSigner.verify_access_token(token) do
      {:ok, claims} ->
        {:ok, claims}

      {:error, reason} ->
        require Logger
        Logger.warning("AuthenticateToken: JWT validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Validates essential JWT claims after signature verification.
  # Joken.verify_and_validate/3 with an empty config validates nothing
  # beyond the signature, so we must check exp here.
  @doc false
  def validate_jwt_claims(claims) do
    JwtSigner.validate_claims(claims)
  end

  defp inject_jwt_context(conn, claims) do
    scopes =
      case claims["scope"] do
        nil -> claims["scopes"] || []
        s when is_binary(s) -> String.split(s, " ")
        s -> s
      end

    conn
    |> assign(:current_user_id, claims["sub"])
    |> assign(:current_client_id, claims["client_id"])
    |> assign(:token_scope, scopes)
    |> assign(:auth_context, %{valid: true, active: true, scope: scopes, jwt: true})
  end

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      error: "unauthorized",
      error_description: message
    })
    |> halt()
  end
end
