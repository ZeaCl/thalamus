defmodule ThalamusWeb.OAuth2.RevocationController do
  @moduledoc """
  OAuth2 Token Revocation Endpoint Controller.

  Implements RFC 7009 - OAuth 2.0 Token Revocation

  This endpoint allows clients to notify the authorization server that
  a token is no longer needed, enabling the server to clean up security
  credentials.

  SOLID Principles Applied:
  - Single Responsibility: Only handles token revocation HTTP requests
  - Dependency Inversion: Depends on TokenRepository through interface
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.{PostgreSQLOAuth2ClientRepository, PostgreSQLTokenRepository}
  alias Thalamus.Domain.ValueObjects.ClientId

  @doc """
  POST /oauth/revoke

  Token revocation endpoint.

  ## Request Parameters (form-urlencoded or JSON)
  - token (required): The token to revoke
  - token_type_hint (optional): hint about token type (access_token, refresh_token)

  ## Authentication
  Requires client authentication (client_id and client_secret in Authorization header or body)

  ## Response
  - 200 OK: Token revoked successfully (or token was already invalid)
  - 400 Bad Request: Invalid request parameters
  - 401 Unauthorized: Client authentication failed

  ## Examples

      # Request
      POST /oauth/revoke
      Authorization: Basic base64(client_id:client_secret)
      Content-Type: application/x-www-form-urlencoded

      token=at_xxxx&token_type_hint=access_token

      # Success Response
      HTTP/1.1 200 OK

  ## Notes
  - Per RFC 7009, the server responds with 200 OK regardless of whether
    the token was valid or not (prevents information leakage)
  - Invalid tokens are silently ignored
  - The token parameter is required
  """
  def create(conn, params) do
    token = get_param(params, "token")
    token_type_hint = get_param(params, "token_type_hint")

    # Authenticate the client making the revocation request
    with {:ok, client_id, client_secret} <- extract_client_credentials(conn, params),
         {:ok, client_id_vo} <- ClientId.from_string(client_id),
         {:ok, _client} <- authenticate_client(client_id_vo, client_secret) do

      # Validate required parameters
      cond do
        is_nil(token) or token == "" ->
          conn
          |> put_status(:bad_request)
          |> json(%{
            error: "invalid_request",
            error_description: "Missing required parameter: token"
          })

        true ->
          # Perform revocation (always returns 200 OK per RFC 7009)
          perform_revocation(conn, token, token_type_hint)
      end
    else
      {:error, :invalid_client} ->
        conn
        |> put_status(:unauthorized)
        |> put_resp_header("www-authenticate", "Basic")
        |> json(%{
          error: "invalid_client",
          error_description: "Client authentication failed"
        })

      {:error, :missing_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> put_resp_header("www-authenticate", "Basic")
        |> json(%{
          error: "invalid_client",
          error_description: "Client credentials required"
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "invalid_request",
          error_description: "Revocation failed: #{inspect(reason)}"
        })
    end
  end

  # Private helper functions

  defp perform_revocation(conn, token, _token_type_hint) do
    # Attempt to revoke the token
    # Per RFC 7009 Section 2.2: respond with 200 OK regardless of outcome
    case PostgreSQLTokenRepository.revoke(token) do
      :ok ->
        # Token successfully revoked
        success_response(conn)

      {:error, :not_found} ->
        # Token not found or already invalid - still return 200 OK
        success_response(conn)

      {:error, _reason} ->
        # Any other error - still return 200 OK to prevent info leakage
        success_response(conn)
    end
  end

  defp success_response(conn) do
    conn
    |> put_status(:ok)
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("pragma", "no-cache")
    |> json(%{})
  end

  defp extract_client_credentials(conn, params) do
    # Try Authorization header first (preferred method)
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded_credentials | _] ->
        decode_basic_auth(encoded_credentials)

      _ ->
        # Fall back to request body parameters
        client_id = get_param(params, "client_id")
        client_secret = get_param(params, "client_secret")

        if client_id && client_secret do
          {:ok, client_id, client_secret}
        else
          {:error, :missing_credentials}
        end
    end
  end

  defp decode_basic_auth(encoded_credentials) do
    case Base.decode64(encoded_credentials) do
      {:ok, credentials} ->
        case String.split(credentials, ":", parts: 2) do
          [client_id, client_secret] ->
            {:ok, client_id, client_secret}

          _ ->
            {:error, :invalid_client}
        end

      :error ->
        {:error, :invalid_client}
    end
  end

  defp authenticate_client(client_id, client_secret) do
    case PostgreSQLOAuth2ClientRepository.find_by_id(client_id) do
      {:ok, client} ->
        # Verify client is active
        if client.status == :active do
          # Verify client secret
          case client.client_secret do
            nil ->
              # Public client - no secret required
              {:ok, client}

            stored_secret ->
              # Confidential client - verify secret
              if Thalamus.Domain.ValueObjects.ClientSecret.verify(stored_secret, client_secret) do
                {:ok, client}
              else
                {:error, :invalid_client}
              end
          end
        else
          {:error, :invalid_client}
        end

      {:error, :not_found} ->
        {:error, :invalid_client}
    end
  end

  defp get_param(params, key) when is_map(params) do
    params[key] || params[String.to_atom(key)]
  end

  defp get_param(_, _), do: nil
end
