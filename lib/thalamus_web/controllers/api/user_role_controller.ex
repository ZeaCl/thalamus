defmodule ThalamusWeb.API.UserRoleController do
  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.{AssignRole, RevokeRole, GetUserRoles, GetEffectiveScopes}
  alias Thalamus.Infrastructure.Repositories.{PostgresqlRoleRepository, PostgreSQLUserRepository}
  alias Thalamus.Infrastructure.Adapters.{RedisCacheAdapter, AuditLoggerImpl}

  # Dependency injection
  @deps %{
    role_repository: PostgresqlRoleRepository,
    user_repository: PostgreSQLUserRepository,
    cache_service: RedisCacheAdapter,
    audit_logger: AuditLoggerImpl
  }

  @doc """
  Assigns a role to a user.

  POST /api/users/:user_id/roles
  Body: {role_id}
  """
  def assign(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    assigned_by = get_current_user_id(conn)

    request = %{
      user_id: user_id,
      role_id: role_id,
      assigned_by: assigned_by
    }

    case AssignRole.execute(request, @deps) do
      {:ok, user_role} ->
        conn
        |> put_status(:created)
        |> json(%{data: user_role})

      {:error, :user_not_active} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "user_not_active", message: "User is not active"})

      {:error, :organization_mismatch} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "organization_mismatch",
          message: "User and role must be in same organization"
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "User or role not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  Revokes a role from a user.

  DELETE /api/users/:user_id/roles/:role_id
  """
  def revoke(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    revoked_by = get_current_user_id(conn)

    request = %{
      user_id: user_id,
      role_id: role_id,
      revoked_by: revoked_by
    }

    case RevokeRole.execute(request, @deps) do
      {:ok, result} ->
        json(conn, %{data: result})

      {:error, :assignment_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "assignment_not_found", message: "User does not have this role"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  Lists all roles assigned to a user.

  GET /api/users/:user_id/roles
  """
  def index(conn, %{"user_id" => user_id}) do
    case GetUserRoles.execute(%{user_id: user_id}, @deps) do
      {:ok, roles} ->
        json(conn, %{data: roles})
    end
  end

  @doc """
  Gets effective scopes for a user (union of all role scopes).

  GET /api/users/:user_id/effective-scopes
  """
  def effective_scopes(conn, %{"user_id" => user_id}) do
    case GetEffectiveScopes.execute(user_id, @deps) do
      {:ok, scopes} ->
        json(conn, %{data: %{user_id: user_id, effective_scopes: scopes}})
    end
  end

  # Private functions

  defp get_current_user_id(conn) do
    case conn.assigns do
      %{current_user: %{id: %Thalamus.Domain.ValueObjects.UserId{} = user_id}} ->
        # Convert UserId value object to plain UUID string
        user_id_string = Thalamus.Domain.ValueObjects.UserId.to_string(user_id)
        String.replace_prefix(user_id_string, "user_", "")

      %{current_user: %{id: user_id}} when is_binary(user_id) ->
        # Already a string, remove prefix if present
        String.replace_prefix(user_id, "user_", "")

      %{user_id: user_id} when is_binary(user_id) ->
        String.replace_prefix(user_id, "user_", "")

      _ ->
        nil
    end
  end
end
