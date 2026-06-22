defmodule Thalamus.Infrastructure.Repositories.PostgreSQLPersonalAccessTokenRepository do
  @moduledoc """
  PostgreSQL implementation of the PersonalAccessToken repository.

  Handles persistence and mapping of PersonalAccessToken domain entities to the database.
  """

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.PersonalAccessTokenSchema
  alias Thalamus.Domain.Entities.PersonalAccessToken

  @doc """
  Finds a token by its UUID.
  """
  def find_by_id(id) when is_binary(id) do
    case Repo.get(PersonalAccessTokenSchema, id) do
      nil -> {:error, :not_found}
      schema -> schema_to_entity(schema)
    end
  end

  @doc """
  Finds a token by its sliced prefix.
  """
  def find_by_prefix(token_prefix) when is_binary(token_prefix) do
    PersonalAccessTokenSchema
    |> where([t], t.token_prefix == ^token_prefix)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> schema_to_entity(schema)
    end
  end

  @doc """
  Saves a PersonalAccessToken entity (insert or update).
  """
  def save(%PersonalAccessToken{} = pat) do
    schema_attrs = entity_to_map(pat)

    existing = if pat.id, do: Repo.get(PersonalAccessTokenSchema, pat.id), else: nil

    result =
      case existing do
        nil ->
          # New token - insert
          PersonalAccessTokenSchema.create_changeset(schema_attrs)
          |> Repo.insert()

        existing_schema ->
          # Existing token - update
          changeset = PersonalAccessTokenSchema.update_changeset(existing_schema, schema_attrs)
          Repo.update(changeset)
      end

    case result do
      {:ok, saved_schema} -> schema_to_entity(saved_schema)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Deletes/revokes a token from the database.
  """
  def delete(id) when is_binary(id) do
    case Repo.get(PersonalAccessTokenSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        case Repo.delete(schema) do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Lists all tokens for a user.
  """
  def list_for_user(user_id) when is_binary(user_id) do
    PersonalAccessTokenSchema
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
    |> Enum.map(fn schema ->
      {:ok, entity} = schema_to_entity(schema)
      entity
    end)
    |> then(&{:ok, &1})
  end

  @doc """
  Marks a token as used asynchronously or inline.
  """
  def mark_as_used(%PersonalAccessToken{} = pat) do
    case Repo.get(PersonalAccessTokenSchema, pat.id) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> PersonalAccessTokenSchema.mark_used_changeset()
        |> Repo.update()
        |> case do
          {:ok, updated_schema} -> schema_to_entity(updated_schema)
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # Helper mappings

  defp schema_to_entity(%PersonalAccessTokenSchema{} = schema) do
    PersonalAccessToken.new(%{
      id: schema.id,
      token_hash: schema.token_hash,
      token_prefix: schema.token_prefix,
      name: schema.name,
      scopes: schema.scopes || [],
      is_active: schema.is_active,
      expires_at: schema.expires_at,
      last_used_at: schema.last_used_at,
      user_id: schema.user_id,
      organization_id: schema.organization_id,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end

  defp entity_to_map(%PersonalAccessToken{} = entity) do
    %{
      id: entity.id,
      token_hash: entity.token_hash,
      token_prefix: entity.token_prefix,
      name: entity.name,
      scopes: entity.scopes,
      is_active: entity.is_active,
      expires_at: entity.expires_at,
      last_used_at: entity.last_used_at,
      user_id: entity.user_id,
      organization_id:
        entity.organization_id &&
          String.replace_prefix(to_string(entity.organization_id), "org_", "")
    }
  end
end
