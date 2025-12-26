defmodule ThalamusWeb.Admin.AdminApiKeyController do
  @moduledoc """
  Admin API Key Management Controller.

  Provides REST API for managing Admin API Keys used for service-to-service authentication.
  These keys allow external services to register OAuth2 clients without manual intervention.

  REQUIRED: Only accessible to super_admin users.

  Endpoints:
  - POST   /api/admin/api-keys          - Create new API key
  - GET    /api/admin/api-keys          - List all API keys
  - GET    /api/admin/api-keys/:id      - Get specific API key
  - DELETE /api/admin/api-keys/:id      - Revoke (deactivate) API key
  - POST   /api/admin/api-keys/:id/rotate - Rotate API key (generate new secret)

  SOLID Principles Applied:
  - Single Responsibility: Only handles HTTP requests for Admin API Keys
  - Dependency Inversion: Uses repositories through interfaces
  """

  use ThalamusWeb, :controller

  alias Thalamus.Domain.Services.AdminApiKeyGenerator
  alias Thalamus.Domain.Entities.AdminApiKey
  alias Thalamus.Infrastructure.Repositories.PostgreSQLAdminApiKeyRepository

  # TODO: Uncomment when authentication plugs are ready
  # plug :require_super_admin

  @doc """
  POST /api/admin/api-keys

  Creates a new Admin API Key.

  ## Request Body
  ```json
  {
    "name": "Sport Backend Registration",
    "description": "API Key for Sport to register as OAuth2 client",
    "scopes": ["clients:write", "clients:read"],
    "expires_at": "2026-12-31T23:59:59Z" // Optional
  }
  ```

  ## Response (201 Created)
  ```json
  {
    "data": {
      "id": "uuid",
      "api_key": "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL", // ⚠️ Only shown once!
      "key_prefix": "ak_dev_vK8m",
      "name": "Sport Backend Registration",
      "scopes": ["clients:write", "clients:read"],
      "is_active": true,
      "expires_at": "2026-12-31T23:59:59Z",
      "created_at": "2025-12-24T10:00:00Z"
    },
    "message": "⚠️ IMPORTANT: Save the api_key in a secure location. It cannot be retrieved later."
  }
  ```

  ## Error Responses
  - 400: Invalid request (missing required fields, invalid scopes)
  - 401: Unauthorized (not authenticated)
  - 403: Forbidden (not super_admin)
  """
  def create(conn, params) do
    current_user_id = get_current_user_id(conn)

    with {:ok, name} <- validate_required_param(params, "name"),
         scopes <- Map.get(params, "scopes", []),
         :ok <- validate_scopes(scopes),
         expires_at <- parse_expiration(params["expires_at"]),
         %{api_key: api_key, key_prefix: key_prefix, key_hash: key_hash} <-
           AdminApiKeyGenerator.generate(),
         {:ok, key_entity} <-
           AdminApiKey.new(%{
             id: Ecto.UUID.generate(),
             key_hash: key_hash,
             key_prefix: key_prefix,
             name: name,
             description: params["description"],
             scopes: scopes,
             expires_at: expires_at,
             created_by_user_id: current_user_id
           }),
         {:ok, saved_key} <- PostgreSQLAdminApiKeyRepository.save(key_entity) do
      # ⚠️ IMPORTANT: Only return api_key in creation response
      response_data =
        saved_key
        |> api_key_to_json()
        |> Map.put(:api_key, api_key)

      conn
      |> put_status(:created)
      |> json(%{
        data: response_data,
        message:
          "⚠️ IMPORTANT: Save the api_key in a secure location. It cannot be retrieved later."
      })
    else
      {:error, :missing_param, field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{field}"})

      {:error, {:invalid_scopes, invalid}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Invalid scopes",
          details: "The following scopes are not allowed: #{Enum.join(invalid, ", ")}",
          valid_scopes: AdminApiKey.valid_scopes()
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to create API key", details: inspect(reason)})
    end
  end

  @doc """
  GET /api/admin/api-keys

  Lists all Admin API Keys.

  NOTE: The full api_key is NOT returned (only the prefix is shown for security).

  ## Query Parameters
  - is_active: Filter by active status (true/false)
  - created_by: Filter by creator user ID

  ## Response (200 OK)
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "key_prefix": "ak_dev_vK8m",  // ← Only prefix, NOT full key
        "name": "Sport Backend Registration",
        "scopes": ["clients:write"],
        "is_active": true,
        "last_used_at": "2025-12-24T15:00:00Z",
        "expires_at": "2026-12-31T23:59:59Z",
        "created_at": "2025-12-24T10:00:00Z"
      }
    ],
    "meta": {
      "count": 1
    }
  }
  ```
  """
  def index(conn, params) do
    filters = build_filters(params)

    case PostgreSQLAdminApiKeyRepository.list(filters) do
      {:ok, api_keys} ->
        conn
        |> put_status(:ok)
        |> json(%{
          data: Enum.map(api_keys, &api_key_to_json/1),
          meta: %{count: length(api_keys)}
        })
    end
  end

  @doc """
  GET /api/admin/api-keys/:id

  Get details of a specific Admin API Key.

  NOTE: The full api_key is NOT returned (only the prefix).

  ## Response (200 OK)
  Same structure as list item.

  ## Error Responses
  - 404: API key not found
  """
  def show(conn, %{"id" => id}) do
    case PostgreSQLAdminApiKeyRepository.find_by_id(id) do
      {:ok, api_key} ->
        conn
        |> put_status(:ok)
        |> json(%{data: api_key_to_json(api_key)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "API key not found"})
    end
  end

  @doc """
  DELETE /api/admin/api-keys/:id

  Revokes (deactivates) an Admin API Key.

  This performs a soft delete by setting is_active to false.
  The key cannot be used for authentication after revocation.

  ## Response (200 OK)
  ```json
  {
    "message": "API key revoked successfully",
    "data": {
      "id": "uuid",
      "is_active": false
    }
  }
  ```

  ## Error Responses
  - 404: API key not found
  """
  def delete(conn, %{"id" => id}) do
    with {:ok, api_key} <- PostgreSQLAdminApiKeyRepository.find_by_id(id),
         {:ok, deactivated} <- AdminApiKey.deactivate(api_key),
         {:ok, saved} <- PostgreSQLAdminApiKeyRepository.save(deactivated) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "API key revoked successfully",
        data: %{
          id: saved.id,
          is_active: saved.is_active
        }
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "API key not found"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to revoke API key", details: inspect(reason)})
    end
  end

  @doc """
  POST /api/admin/api-keys/:id/rotate

  Rotates an Admin API Key by generating a new secret.

  The old key is immediately invalidated and replaced with a new one.
  Use this for periodic key rotation or when a key may have been compromised.

  ## Response (200 OK)
  ```json
  {
    "data": {
      "id": "uuid",
      "api_key": "ak_dev_NEW_RANDOM_KEY",  // ⚠️ New key (only shown once)
      "key_prefix": "ak_dev_NEW_r",
      "name": "Sport Backend Registration",
      "scopes": ["clients:write"]
    },
    "message": "⚠️ The old API key is no longer valid. Save the new api_key securely."
  }
  ```

  ## Error Responses
  - 404: API key not found
  """
  def rotate(conn, %{"id" => id}) do
    with {:ok, old_key} <- PostgreSQLAdminApiKeyRepository.find_by_id(id),
         %{api_key: new_api_key, key_prefix: new_prefix, key_hash: new_hash} <-
           AdminApiKeyGenerator.generate(),
         updated_key <- %{
           old_key
           | key_hash: new_hash,
             key_prefix: new_prefix,
             updated_at: DateTime.truncate(DateTime.utc_now(), :second)
         },
         {:ok, saved_key} <- PostgreSQLAdminApiKeyRepository.save(updated_key) do
      response_data =
        saved_key
        |> api_key_to_json()
        |> Map.put(:api_key, new_api_key)

      conn
      |> put_status(:ok)
      |> json(%{
        data: response_data,
        message: "⚠️ The old API key is no longer valid. Save the new api_key securely."
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "API key not found"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to rotate API key", details: inspect(reason)})
    end
  end

  # Private helper functions

  defp get_current_user_id(conn) do
    # TODO: Extract from conn.assigns.current_user.id once auth is implemented
    # For now, return nil (will be set in AdminApiKey entity)
    Map.get(conn.assigns, :current_user_id)
  end

  defp validate_required_param(params, key) do
    case Map.get(params, key) do
      nil -> {:error, :missing_param, key}
      "" -> {:error, :missing_param, key}
      value -> {:ok, value}
    end
  end

  defp validate_scopes(scopes) when is_list(scopes) do
    valid_scopes = AdminApiKey.valid_scopes()
    invalid_scopes = Enum.reject(scopes, fn scope -> scope in valid_scopes end)

    if Enum.empty?(invalid_scopes) do
      :ok
    else
      {:error, {:invalid_scopes, invalid_scopes}}
    end
  end

  defp validate_scopes(_), do: {:error, :scopes_must_be_list}

  defp parse_expiration(nil), do: nil

  defp parse_expiration(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> DateTime.truncate(datetime, :second)
      {:error, _} -> nil
    end
  end

  defp parse_expiration(_), do: nil

  defp build_filters(params) do
    %{}
    |> maybe_add_filter(:is_active, params["is_active"])
    |> maybe_add_filter(:created_by_user_id, params["created_by"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters

  defp maybe_add_filter(filters, :is_active, value) when value in ["true", "false"] do
    Map.put(filters, :is_active, value == "true")
  end

  defp maybe_add_filter(filters, key, value) do
    Map.put(filters, key, value)
  end

  defp api_key_to_json(%AdminApiKey{} = api_key) do
    %{
      id: api_key.id,
      key_prefix: api_key.key_prefix,
      name: api_key.name,
      description: api_key.description,
      scopes: api_key.scopes,
      is_active: api_key.is_active,
      last_used_at: api_key.last_used_at,
      expires_at: api_key.expires_at,
      created_at: api_key.created_at,
      updated_at: api_key.updated_at
    }
  end
end
