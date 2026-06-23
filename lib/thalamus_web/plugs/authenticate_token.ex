defmodule ThalamusWeb.Plugs.AuthenticateToken do
  @moduledoc """
  Authentication Plug for API endpoints.

  Validates Bearer tokens in the Authorization header and injects
  authenticated user/client context into the connection.

  This plug implements token-based authentication for the API:
  - Extracts token from Authorization header
  - Validates token using ValidateToken use case
  - Injects authenticated context into conn.assigns
  - Returns 401 Unauthorized if token is missing or invalid

  SOLID Principles Applied:
  - Single Responsibility: Only handles token authentication
  - Dependency Inversion: Uses ValidateToken use case through interface

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
      {:ok, validation_result} ->
        if validation_result.valid and validation_result.active do
          # Token is valid and active - inject context
          conn
          |> assign(:current_user_id, validation_result.user_id)
          |> assign(:current_client_id, validation_result.client_id)
          |> assign(:token_scope, validation_result.scope)
          |> assign(:auth_context, validation_result)
        else
          # Token is invalid or inactive (expired, revoked, or not found)
          cond do
            Map.get(validation_result, :revoked, false) ->
              unauthorized(conn, "Token has been revoked")

            Map.get(validation_result, :expired, false) ->
              unauthorized(conn, "Token has expired")

            !validation_result.active ->
              unauthorized(conn, "Invalid or inactive token")

            true ->
              unauthorized(conn, "Token validation failed")
          end
        end

      {:error, :invalid_token_format} ->
        unauthorized(conn, "Invalid token format")
    end
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
