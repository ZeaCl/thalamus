defmodule Thalamus.Infrastructure.Repositories.PostgreSQLUserIdentityRepository do
  @moduledoc """
  PostgreSQL implementation of UserIdentityRepository port.
  """

  @behaviour Thalamus.Application.Ports.UserIdentityRepository

  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.UserIdentity
  alias Thalamus.Infrastructure.Persistence.Schemas.UserIdentitySchema

  import Ecto.Query

  @impl true
  def find_by_provider_and_uid(provider, uid) when is_binary(provider) and is_binary(uid) do
    provider_str = String.downcase(provider)

    query =
      from u in UserIdentitySchema,
        where: u.provider == ^provider_str and u.provider_uid == ^uid

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_entity(schema)}
    end
  end

  @impl true
  def find_all_by_user_id(user_id) when is_binary(user_id) do
    query =
      from u in UserIdentitySchema,
        where: u.user_id == ^user_id,
        order_by: [desc: u.inserted_at]

    identities =
      Repo.all(query)
      |> Enum.map(&to_entity/1)

    {:ok, identities}
  end

  @impl true
  def find_by_user_and_provider(user_id, provider)
      when is_binary(user_id) and is_binary(provider) do
    provider_str = String.downcase(provider)

    query =
      from u in UserIdentitySchema,
        where: u.user_id == ^user_id and u.provider == ^provider_str

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_entity(schema)}
    end
  end

  @impl true
  def save(%UserIdentity{} = identity) do
    params = %{
      id: identity.id,
      user_id: identity.user_id,
      provider: identity.provider,
      provider_uid: identity.provider_uid,
      email: identity.email,
      metadata: identity.metadata
    }

    schema =
      if identity.id do
        Repo.get(UserIdentitySchema, identity.id) || %UserIdentitySchema{}
      else
        %UserIdentitySchema{}
      end

    changeset = UserIdentitySchema.changeset(schema, params)

    case Repo.insert_or_update(changeset) do
      {:ok, saved_schema} -> {:ok, to_entity(saved_schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete(id) when is_binary(id) do
    case Repo.get(UserIdentitySchema, id) do
      nil -> {:error, :not_found}
      schema -> Repo.delete(schema) |> handle_delete_result()
    end
  end

  defp handle_delete_result({:ok, _}), do: :ok
  defp handle_delete_result({:error, reason}), do: {:error, reason}

  defp to_entity(%UserIdentitySchema{} = schema) do
    %UserIdentity{
      id: schema.id,
      user_id: schema.user_id,
      provider: schema.provider,
      provider_uid: schema.provider_uid,
      email: schema.email,
      metadata: schema.metadata || %{},
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
