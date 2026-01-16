defmodule ThalamusWeb.OAuth2.IntrospectionController do
  @moduledoc """
  OAuth2 Token Introspection Endpoint Controller.

  Implements RFC 7662 - OAuth 2.0 Token Introspection

  This endpoint allows resource servers to query the authorization server
  to determine the state and metadata of a token.

  SOLID Principles Applied:
  - Single Responsibility: Only handles token introspection HTTP requests
  - Dependency Inversion: Depends on Use Cases, not implementations
  """

  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.CachedValidateToken

  # Dependencies
  @deps %{
    token_repository: Thalamus.Infrastructure.Repositories.PostgreSQLTokenRepository,
    user_repository: Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository,
    cache_service: Thalamus.Infrastructure.Adapters.RedisCacheAdapter
  }

  @doc """
  POST /oauth/introspect

  Token introspection endpoint for validating and getting metadata about a token.

  ## Request Parameters (form-urlencoded or JSON)
  - token (required): The token to introspect
  - token_type_hint (optional): hint about the type of token (access_token, refresh_token)

  ## Authentication
  Requires client authentication (client_id and client_secret in Authorization header or body)

  ## Response
  Returns token metadata including:
  - active: boolean indicating if token is active
  - scope: space-separated list of scopes
  - client_id: identifier of the client
  - username: username of the resource owner (if available)
  - token_type: type of the token
  - exp: expiration timestamp
  - iat: issued at timestamp
  - sub: subject identifier (user_id)

  ## Examples

      # Active token
      {
        "active": true,
        "scope": "openid profile email",
        "client_id": "client_abc123",
        "username": "user@example.com",
        "token_type": "Bearer",
        "exp": 1640995200,
        "iat": 1640991600,
        "sub": "user_123"
      }

      # Inactive token
      {
        "active": false
      }
  """
  def create(conn, params) do
    token = get_param(params, "token")

    # TODO: Authenticate the client making the introspection request
    # For now, we'll allow any request (in production, this MUST be authenticated)

    cond do
      is_nil(token) or token == "" ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "invalid_request",
          error_description: "Missing required parameter: token"
        })

      true ->
        perform_introspection(conn, token)
    end
  end

  # Private functions

  defp perform_introspection(conn, token) do
    case CachedValidateToken.execute(token, @deps) do
      {:ok, validation_result} ->
        # Convert to RFC 7662 format
        response = build_introspection_response(validation_result)

        conn
        |> put_status(:ok)
        |> put_resp_header("cache-control", "no-store")
        |> put_resp_header("pragma", "no-cache")
        |> json(response)

      {:error, :invalid_token_format} ->
        # Invalid token format - return inactive
        conn
        |> put_status(:ok)
        |> json(%{active: false})

      {:error, _reason} ->
        # Any other error - return inactive
        conn
        |> put_status(:ok)
        |> json(%{active: false})
    end
  end

  defp build_introspection_response(%{valid: true, active: true} = result) do
    response = %{
      active: true,
      scope: Enum.join(result.scope, " "),
      client_id: result.client_id,
      token_type: "Bearer"
    }

    # Add optional fields if present
    response =
      if result.user_id do
        # Fetch user email if we have user_id
        email = get_user_email(result.user_id)

        response
        |> Map.put(:sub, result.user_id)
        |> Map.put(:user_id, result.user_id)
        |> Map.put(:username, result.user_id)
        |> maybe_put(:email, email)
      else
        response
      end

    response =
      if result.organization_id do
        response
        |> Map.put(:organization_id, result.organization_id)
        # Campaigns usa ambos nombres
        |> Map.put(:tenant_id, result.organization_id)
      else
        response
      end

    response =
      if result.exp do
        Map.put(response, :exp, DateTime.to_unix(result.exp))
      else
        response
      end

    response =
      if result.iat do
        Map.put(response, :iat, DateTime.to_unix(result.iat))
      else
        response
      end

    # Add agent-specific fields if present
    response =
      if result.agent_type do
        response
        |> Map.put(:agent_type, result.agent_type)
        |> maybe_put(:delegated_by, result.delegated_by)
        |> maybe_put(:delegation_chain, result.delegation_chain)
        |> maybe_put(:delegation_depth, result.delegation_depth)
        |> maybe_put(:task_id, result.task_id)
        |> maybe_put(:task_type, result.task_type)
        |> maybe_put(:task_scopes, result.task_scopes)
        |> maybe_put(:max_operations, result.max_operations)
        |> maybe_put(:operations_remaining, result.operations_remaining)
        |> maybe_put(:expires_on_completion, result.expires_on_completion)
        |> maybe_put(:intent_description, result.intent_description)
        |> maybe_put(:orchestrator_id, result.orchestrator_id)
        |> maybe_put(:environment, result.environment)
      else
        response
      end

    response
  end

  defp build_introspection_response(_result) do
    # Token is not active
    %{active: false}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp get_user_email(user_id) when is_binary(user_id) do
    alias Thalamus.Domain.ValueObjects.UserId
    alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository

    with {:ok, user_id_vo} <- UserId.from_string(user_id),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id_vo) do
      Thalamus.Domain.ValueObjects.Email.to_string(user.email)
    else
      _ -> nil
    end
  end

  defp get_user_email(_), do: nil

  defp get_param(params, key) when is_map(params) do
    params[key] || params[String.to_atom(key)]
  end

  defp get_param(_, _), do: nil
end
