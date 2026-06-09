defmodule ThalamusWeb.API.UserController do
  @moduledoc """
  User Management API Controller.

  Provides REST API for user management operations:
  - List users
  - Get user details
  - Create user
  - Update user
  - Delete user
  - User verification

  SOLID Principles Applied:
  - Single Responsibility: Only handles HTTP user management requests
  - Dependency Inversion: Depends on repositories through interfaces
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository
  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.{UserId, Email}

  # TODO: Add proper authentication middleware
  # plug :authenticate_api_request
  # plug :require_scope, ["users:read"] when action in [:index, :show]
  # plug :require_scope, ["users:write"] when action in [:create, :update, :delete]

  @doc """
  GET /api/users

  List all users with optional filtering.

  ## Query Parameters
  - status: Filter by status (active, suspended, etc.)
  - verified: Filter by verification status (true/false)
  - organization_id: Filter by organization
  - username: Filter by name or email (partial ILIKE match)
  - limit: Number of results (default: 50, max: 100)
  - offset: Pagination offset

  ## Response
  200 OK with array of user objects
  """
  def index(conn, params) do
    filters = build_filters(params)

    case PostgreSQLUserRepository.list(filters) do
      {:ok, users} ->
        conn
        |> put_status(:ok)
        |> json(%{
          data: Enum.map(users, &user_to_json/1),
          meta: %{
            count: length(users),
            filters: filters
          }
        })
    end
  end

  @doc """
  GET /api/users/:id

  Get a specific user by ID.

  ## Path Parameters
  - id: User UUID

  ## Response
  - 200 OK: User found
  - 404 Not Found: User not found
  """
  def show(conn, %{"id" => id}) do
    case UserId.from_string(id) do
      {:ok, user_id} ->
        case PostgreSQLUserRepository.find_by_id(user_id) do
          {:ok, user} ->
            conn
            |> put_status(:ok)
            |> json(%{data: user_to_json(user)})

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "User not found"})

          {:error, :invalid_uuid} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Invalid user ID format"})
        end

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid user ID format"})
    end
  end

  @doc """
  POST /api/users

  Create a new user.

  ## Request Body (JSON)
  {
    "email": "user@example.com",
    "password": "SecurePassword123!"
  }

  ## Response
  - 201 Created: User created successfully
  - 400 Bad Request: Invalid input
  - 409 Conflict: Email already exists
  """
  def create(conn, params) do
    with {:ok, email_string} <- get_required_param(params, "email"),
         {:ok, password} <- get_required_param(params, "password"),
         is_agent = params["is_agent"] == true || params["is_agent"] == "true",
         create_result =
           if(is_agent,
             do:
               User.register_agent(
                 params["name"] || "Agent User",
                 email_string,
                 password,
                 params["agent_config"] || %{}
               ),
             else: User.register(email_string, password)
           ),
         {:ok, user} <- create_result,
         {:ok, saved_user} <- PostgreSQLUserRepository.save(user) do
      conn
      |> put_status(:created)
      |> json(%{
        data: user_to_json(saved_user),
        message: "User created successfully"
      })
    else
      {:error, :missing_parameter, param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{param}"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)

        # Check if it's a unique constraint violation (email already exists)
        status =
          if has_unique_constraint_error?(changeset, :email), do: :conflict, else: :bad_request

        conn
        |> put_status(status)
        |> json(%{error: "Validation failed", details: errors})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create user", details: inspect(reason)})
    end
  end

  @doc """
  PATCH /api/users/:id

  Update a user.

  ## Path Parameters
  - id: User UUID

  ## Request Body (JSON)
  {
    "status": "active|suspended|deactivated"
  }

  ## Response
  - 200 OK: User updated
  - 404 Not Found: User not found
  - 400 Bad Request: Invalid input
  """
  def update(conn, %{"id" => id} = params) do
    # Unwrap "user" key if SDK wraps data (thalamus-js sends { user: data })
    update_params = params["user"] || params
    with {:ok, user_id} <- UserId.from_string(id),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         {:ok, updated_user} <- apply_updates(user, update_params),
         {:ok, saved_user} <- PostgreSQLUserRepository.save(updated_user) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: user_to_json(saved_user),
        message: "User updated successfully"
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to update user", details: inspect(reason)})
    end
  end

  @doc """
  DELETE /api/users/:id

  Delete a user (soft delete by deactivating).

  ## Path Parameters
  - id: User UUID

  ## Response
  - 204 No Content: User deleted
  - 404 Not Found: User not found
  """
  def delete(conn, %{"id" => id}) do
    with {:ok, user_id} <- UserId.from_string(id),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         {:ok, _deactivated_user} <- User.deactivate(user),
         :ok <- PostgreSQLUserRepository.delete(user_id) do
      conn
      |> put_status(:no_content)
      |> json(%{})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to delete user", details: inspect(reason)})
    end
  end

  # Private helper functions

  defp build_filters(params) do
    filters = %{}

    filters =
      if status = params["status"] do
        Map.put(filters, :status, String.to_existing_atom(status))
      else
        filters
      end

    filters =
      if verified = params["verified"] do
        Map.put(filters, :verified, verified == "true")
      else
        filters
      end

    filters =
      if org_id = params["organization_id"] do
        Map.put(filters, :organization_id, org_id)
      else
        filters
      end

    filters =
      if username = params["username"] do
        Map.put(filters, :username, username)
      else
        filters
      end

    filters =
      if limit = params["limit"] do
        limit_int = min(String.to_integer(limit), 100)
        Map.put(filters, :limit, limit_int)
      else
        Map.put(filters, :limit, 50)
      end

    filters =
      if offset = params["offset"] do
        Map.put(filters, :offset, String.to_integer(offset))
      else
        filters
      end

    filters
  end

  defp user_to_json(%User{} = user) do
    %{
      id: UserId.to_string(user.id),
      email: Email.to_string(user.email),
      name: user.name,
      avatar_url: user.avatar_url,
      status: user.status,
      verified: !is_nil(user.verified_at),
      verified_at: user.verified_at,
      last_login_at: user.last_login_at,
      mfa_enabled: User.mfa_enabled?(user),
      created_at: user.created_at,
      updated_at: user.updated_at,
      is_agent: user.is_agent,
      agent_config: user.agent_config
    }
  end

  defp get_required_param(params, key) do
    case params[key] do
      nil -> {:error, :missing_parameter, key}
      "" -> {:error, :missing_parameter, key}
      value -> {:ok, value}
    end
  end

  defp apply_updates(user, params) do
    # Apply status update if present
    user =
      case params["status"] do
        "suspended" ->
          {:ok, updated} = User.suspend(user)
          updated

        "active" ->
          {:ok, updated} = User.reactivate(user)
          updated

        "deactivated" ->
          {:ok, updated} = User.deactivate(user)
          updated

        _ ->
          user
      end

    # Apply name update if present
    user =
      if name = params["name"] do
        %{user | name: name}
      else
        user
      end

    # Apply agent_config update if present
    user =
      if agent_config = params["agent_config"] do
        %{user | agent_config: agent_config}
      else
        user
      end

    {:ok, user}
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp has_unique_constraint_error?(changeset, field) do
    changeset.errors
    |> Enum.any?(fn {error_field, {_message, opts}} ->
      error_field == field && Keyword.get(opts, :constraint) == :unique
    end)
  end
end
