defmodule Thalamus.Infrastructure.Repositories.PostgresqlRoleRepository do
  @moduledoc """
  PostgreSQL implementation of RoleRepository port.

  SOLID Principles:
  - Single Responsibility: Only handles role persistence
  - Dependency Inversion: Implements port defined in application layer
  """

  @behaviour Thalamus.Application.Ports.RoleRepository

  import Ecto.Query
  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.Role
  alias Thalamus.Infrastructure.Persistence.Schemas.{RoleSchema, UserRoleSchema}

  @impl true
  def save(%Role{id: nil} = role) do
    %RoleSchema{}
    |> RoleSchema.changeset(to_map(role))
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def save(%Role{id: id} = role) do
    case Repo.get(RoleSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> RoleSchema.changeset(to_map(role))
        |> Repo.update()
        |> case do
          {:ok, updated_schema} -> {:ok, to_domain(updated_schema)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def find_by_id(id) do
    case Repo.get(RoleSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def find_by_name(organization_id, name) do
    org_uuid = String.replace_prefix(to_string(organization_id), "org_", "")

    query =
      from r in RoleSchema,
        where: r.organization_id == ^org_uuid,
        where: fragment("lower(?) = lower(?)", r.name, ^name)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def list_by_organization(organization_id) do
    org_uuid = String.replace_prefix(to_string(organization_id), "org_", "")

    query =
      from r in RoleSchema,
        where: r.organization_id == ^org_uuid,
        order_by: [asc: r.name]

    roles =
      query
      |> Repo.all()
      |> Enum.map(&to_domain/1)

    {:ok, roles}
  end

  @impl true
  def delete(id) do
    case Repo.get(RoleSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        case Repo.delete(schema) do
          {:ok, _} -> {:ok, 1}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def assign_to_user(user_id, role_id, assigned_by) do
    attrs = %{
      user_id: user_id,
      role_id: role_id,
      assigned_by: assigned_by
    }

    %UserRoleSchema{}
    |> UserRoleSchema.changeset(attrs)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:user_id, :role_id]
    )
    |> case do
      {:ok, user_role} ->
        {:ok,
         %{
           user_id: user_role.user_id,
           role_id: user_role.role_id,
           assigned_at: user_role.assigned_at
         }}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  def revoke_from_user(user_id, role_id) do
    query =
      from ur in UserRoleSchema,
        where: ur.user_id == ^user_id,
        where: ur.role_id == ^role_id

    case Repo.delete_all(query) do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
      # Multiple deleted (shouldn't happen due to unique constraint)
      {_, _} -> :ok
    end
  end

  @impl true
  def get_user_roles(user_id) do
    query =
      from r in RoleSchema,
        join: ur in UserRoleSchema,
        on: ur.role_id == r.id,
        where: ur.user_id == ^user_id,
        order_by: [asc: r.name]

    roles =
      query
      |> Repo.all()
      |> Enum.map(&to_domain/1)

    {:ok, roles}
  end

  @impl true
  def get_users_with_role(role_id) do
    query =
      from ur in UserRoleSchema,
        where: ur.role_id == ^role_id,
        select: ur.user_id

    user_ids = Repo.all(query)
    {:ok, user_ids}
  end

  # Private functions

  defp to_domain(%RoleSchema{} = schema) do
    %Role{
      id: schema.id,
      organization_id: if(schema.organization_id, do: "org_" <> schema.organization_id, else: nil),
      name: schema.name,
      description: schema.description,
      scopes: schema.scopes || [],
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp to_map(%Role{} = role) do
    org_id = role.organization_id && String.replace_prefix(to_string(role.organization_id), "org_", "")

    %{
      id: role.id,
      organization_id: org_id,
      name: role.name,
      description: role.description,
      scopes: role.scopes
    }
  end
end
