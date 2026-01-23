defmodule ThalamusWeb.API.RoleController do
  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.{CreateRole, UpdateRole, DeleteRole, ListRoles}
  alias Thalamus.Infrastructure.Repositories.PostgresqlRoleRepository
  alias Thalamus.Infrastructure.Adapters.RedisCacheAdapter

  # Dependency injection
  @deps %{
    role_repository: PostgresqlRoleRepository,
    cache_service: RedisCacheAdapter
  }

  @doc """
  Lists all roles for the authenticated user's organization.

  GET /api/roles
  """
  def index(conn, _params) do
    organization_id = get_organization_id(conn)

    case ListRoles.execute(%{organization_id: organization_id}, @deps) do
      {:ok, roles} ->
        json(conn, %{data: roles})
    end
  end

  @doc """
  Creates a new role in the organization.

  POST /api/roles
  Body: {name, description?, scopes}
  """
  def create(conn, params) do
    organization_id = get_organization_id(conn)

    request = %{
      organization_id: organization_id,
      name: params["name"],
      description: params["description"],
      scopes: params["scopes"] || []
    }

    case CreateRole.execute(request, @deps) do
      {:ok, role} ->
        conn
        |> put_status(:created)
        |> json(%{data: role})

      {:error, :duplicate_role_name} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "duplicate_role_name", message: "Role name already exists in organization"})

      {:error, :invalid_role_name} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_role_name", message: "Role name is invalid"})

      {:error, :invalid_name} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_role_name", message: "Role name is invalid"})

      {:error, :invalid_scope_format} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_scope_format", message: "One or more scopes have invalid format"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  Shows a single role.

  GET /api/roles/:id
  """
  def show(conn, %{"id" => id}) do
    organization_id = get_organization_id(conn)

    case @deps.role_repository.find_by_id(id) do
      {:ok, role} ->
        if role.organization_id == organization_id do
          json(conn, %{data: role})
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden"})
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "role not found"})
    end
  end

  @doc """
  Updates a role's scopes.

  PATCH /api/roles/:id
  Body: {scopes}
  """
  def update(conn, %{"id" => id, "scopes" => scopes}) do
    organization_id = get_organization_id(conn)

    # Verify organization ownership
    with {:ok, role} <- @deps.role_repository.find_by_id(id),
         :ok <- validate_organization(role, organization_id),
         {:ok, result} <- UpdateRole.execute(%{role_id: id, scopes: scopes}, @deps) do
      json(conn, %{data: result.role, invalidated_cache_for: result.invalidated_cache_for})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "role not found"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  Deletes a role.

  DELETE /api/roles/:id
  """
  def delete(conn, %{"id" => id}) do
    organization_id = get_organization_id(conn)

    # Verify organization ownership
    with {:ok, role} <- @deps.role_repository.find_by_id(id),
         :ok <- validate_organization(role, organization_id),
         {:ok, result} <- DeleteRole.execute(%{role_id: id}, @deps) do
      json(conn, %{
        deleted: true,
        deleted_role_id: result.deleted_role_id,
        invalidated_cache_for: result.invalidated_cache_for
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "role not found"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  # Private functions

  defp get_organization_id(conn) do
    case conn.assigns do
      %{current_user: %{organization_id: org_id}} -> org_id
      %{organization_id: org_id} -> org_id
      _ -> nil
    end
  end

  defp validate_organization(role, organization_id) do
    if role.organization_id == organization_id do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
