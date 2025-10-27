defmodule ThalamusWeb.OAuth2.TokenController do
  @moduledoc """
  OAuth2 Token Endpoint Controller.

  Handles OAuth2 token requests for all grant types:
  - client_credentials
  - authorization_code
  - refresh_token
  - password (deprecated)

  Implements RFC 6749 - OAuth 2.0 Framework
  Implements RFC 7636 - PKCE

  SOLID Principles Applied:
  - Single Responsibility: Only handles HTTP token requests
  - Dependency Inversion: Depends on Use Cases, not implementations
  """

  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.GenerateTokens
  alias Thalamus.Application.DTOs.{TokenRequest, TokenResponse}

  # Dependencies (repositories) - injected via config or Application context
  @deps %{
    oauth2_client_repository:
      Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepository,
    user_repository: Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository,
    token_repository: Thalamus.Infrastructure.Repositories.PostgreSQLTokenRepository,
    audit_logger: Thalamus.Infrastructure.Adapters.AuditLoggerImpl
  }

  @doc """
  POST /oauth/token

  OAuth2 token endpoint for all grant types.

  ## Request Parameters (form-urlencoded or JSON)
  - grant_type (required): authorization_code, client_credentials, refresh_token, password
  - client_id (required): OAuth2 client identifier
  - client_secret (required for confidential clients)
  - code (required for authorization_code grant)
  - redirect_uri (required for authorization_code grant)
  - refresh_token (required for refresh_token grant)
  - code_verifier (optional, for PKCE)
  - scope (optional)

  ## Response
  - 200 OK: Token generated successfully
  - 400 Bad Request: Invalid request parameters
  - 401 Unauthorized: Invalid client credentials
  - 403 Forbidden: Client not authorized for this grant type
  """
  def create(conn, params) do
    # Extract request parameters
    token_params = extract_token_params(params)

    # Create TokenRequest DTO
    case TokenRequest.new(token_params) do
      {:ok, token_request} ->
        # Execute GenerateTokens use case
        case GenerateTokens.execute(token_request, @deps) do
          {:ok, %TokenResponse{} = token_response} ->
            # Success - return token response
            conn
            |> put_status(:ok)
            |> put_resp_header("cache-control", "no-store")
            |> put_resp_header("pragma", "no-cache")
            |> json(TokenResponse.to_map(token_response))

          {:error, :not_found} ->
            oauth2_error(conn, "invalid_client", "Client authentication failed", :unauthorized)

          {:error, :client_inactive} ->
            oauth2_error(conn, "invalid_client", "Client is not active", :unauthorized)

          {:error, :invalid_client_secret} ->
            oauth2_error(conn, "invalid_client", "Invalid client credentials", :unauthorized)

          {:error, :unsupported_grant_type} ->
            oauth2_error(
              conn,
              "unsupported_grant_type",
              "The authorization grant type is not supported",
              :bad_request
            )

          {:error, :invalid_scope} ->
            oauth2_error(
              conn,
              "invalid_scope",
              "The requested scope is invalid or exceeds the scope granted",
              :bad_request
            )

          {:error, :invalid_redirect_uri} ->
            oauth2_error(
              conn,
              "invalid_grant",
              "Invalid redirect URI",
              :bad_request
            )

          {:error, :invalid_pkce_verifier} ->
            oauth2_error(
              conn,
              "invalid_grant",
              "PKCE verification failed",
              :bad_request
            )

          {:error, :pkce_verifier_required} ->
            oauth2_error(
              conn,
              "invalid_grant",
              "PKCE code verifier required",
              :bad_request
            )

          {:error, :token_client_mismatch} ->
            oauth2_error(
              conn,
              "invalid_grant",
              "Token was not issued to this client",
              :bad_request
            )

          {:error, :deprecated_grant_type} ->
            oauth2_error(
              conn,
              "unsupported_grant_type",
              "Password grant type is deprecated. Use authorization_code with PKCE instead",
              :bad_request
            )

          {:error, reason} ->
            oauth2_error(
              conn,
              "invalid_request",
              "Token generation failed: #{inspect(reason)}",
              :bad_request
            )
        end

      {:error, reason} ->
        oauth2_error(
          conn,
          "invalid_request",
          "Invalid token request: #{inspect(reason)}",
          :bad_request
        )
    end
  end

  # Private helper functions

  defp extract_token_params(params) do
    %{
      grant_type: get_param(params, "grant_type"),
      client_id: get_param(params, "client_id"),
      client_secret: get_param(params, "client_secret"),
      code: get_param(params, "code"),
      redirect_uri: get_param(params, "redirect_uri"),
      refresh_token: get_param(params, "refresh_token"),
      code_verifier: get_param(params, "code_verifier"),
      scope: get_param(params, "scope"),
      username: get_param(params, "username"),
      password: get_param(params, "password")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp get_param(params, key) when is_map(params) do
    # Support both string and atom keys
    params[key] || params[String.to_atom(key)]
  end

  defp get_param(_, _), do: nil

  # OAuth2 error response format (RFC 6749 Section 5.2)
  defp oauth2_error(conn, error_code, description, status) do
    conn
    |> put_status(status)
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("pragma", "no-cache")
    |> json(%{
      error: error_code,
      error_description: description
    })
  end
end
