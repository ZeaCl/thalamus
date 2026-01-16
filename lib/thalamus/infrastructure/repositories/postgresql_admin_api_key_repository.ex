defmodule Thalamus.Infrastructure.Repositories.PostgreSQLAdminApiKeyRepository do
  @moduledoc """
  PostgreSQL implementation of the AdminApiKeyRepository port.

  This adapter converts between AdminApiKey domain entities and database schemas.

  SOLID Principles Applied:
  - Single Responsibility: Only handles AdminApiKey persistence
  - Dependency Inversion: Implements the port defined by Application layer
  - Interface Segregation: Implements only AdminApiKeyRepository interface
  """

  @behaviour Thalamus.Application.Ports.AdminApiKeyRepository

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.AdminApiKeySchema
  alias Thalamus.Domain.Entities.AdminApiKey

  @impl true
  def find_by_id(id) when is_binary(id) do
    case Repo.get(AdminApiKeySchema, id) do
      nil -> {:error, :not_found}
      schema -> schema_to_entity(schema)
    end
  end

  @impl true
  def find_by_prefix(key_prefix) when is_binary(key_prefix) do
    AdminApiKeySchema
    |> where([k], k.key_prefix == ^key_prefix)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> schema_to_entity(schema)
    end
  end

  @impl true
  def save(%AdminApiKey{} = admin_api_key) do
    schema_attrs = entity_to_map(admin_api_key)

    # Check if key exists in database
    existing = if admin_api_key.id, do: Repo.get(AdminApiKeySchema, admin_api_key.id), else: nil

    result =
      case existing do
        nil ->
          # New key - insert
          AdminApiKeySchema.create_changeset(schema_attrs)
          |> Repo.insert()

        existing_schema ->
          # Existing key - determine if this is a rotation or normal update
          is_rotation =
            existing_schema.key_hash != admin_api_key.key_hash or
              existing_schema.key_prefix != admin_api_key.key_prefix

          changeset =
            if is_rotation do
              AdminApiKeySchema.rotate_changeset(existing_schema, schema_attrs)
            else
              AdminApiKeySchema.update_changeset(existing_schema, schema_attrs)
            end

          Repo.update(changeset)
      end

    case result do
      {:ok, saved_schema} -> schema_to_entity(saved_schema)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete(id) when is_binary(id) do
    case Repo.get(AdminApiKeySchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        case Repo.delete(schema) do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def list(filters \\ %{}) do
    query = build_query(filters)
    schemas = Repo.all(query)

    entities =
      Enum.map(schemas, fn schema ->
        {:ok, entity} = schema_to_entity(schema)
        entity
      end)

    {:ok, entities}
  end

  @impl true
  def list_active do
    now = DateTime.utc_now()

    query =
      from k in AdminApiKeySchema,
        where: k.is_active == true,
        where: is_nil(k.expires_at) or k.expires_at > ^now,
        order_by: [desc: k.inserted_at]

    schemas = Repo.all(query)

    entities =
      Enum.map(schemas, fn schema ->
        {:ok, entity} = schema_to_entity(schema)
        entity
      end)

    {:ok, entities}
  end

  # Private helper functions

  defp build_query(filters) do
    Enum.reduce(filters, AdminApiKeySchema, fn
      {:is_active, is_active}, query ->
        where(query, [k], k.is_active == ^is_active)

      {:created_by_user_id, user_id}, query ->
        where(query, [k], k.created_by_user_id == ^user_id)

      {:scopes, scopes}, query when is_list(scopes) ->
        # Return keys that have ANY of the requested scopes
        where(query, [k], fragment("? && ?", k.scopes, ^scopes))

      _other, query ->
        query
    end)
    |> order_by([k], desc: k.inserted_at)
  end

  defp schema_to_entity(%AdminApiKeySchema{} = schema) do
    AdminApiKey.new(%{
      id: schema.id,
      key_hash: schema.key_hash,
      key_prefix: schema.key_prefix,
      name: schema.name,
      description: schema.description,
      scopes: schema.scopes || [],
      is_active: schema.is_active,
      expires_at: schema.expires_at,
      last_used_at: schema.last_used_at,
      created_by_user_id: schema.created_by_user_id,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end

  defp entity_to_map(%AdminApiKey{} = entity) do
    %{
      id: entity.id,
      key_hash: entity.key_hash,
      key_prefix: entity.key_prefix,
      name: entity.name,
      description: entity.description,
      scopes: entity.scopes,
      is_active: entity.is_active,
      expires_at: entity.expires_at,
      last_used_at: entity.last_used_at,
      created_by_user_id: entity.created_by_user_id
    }
  end
end
