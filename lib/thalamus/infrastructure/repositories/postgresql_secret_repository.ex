defmodule Thalamus.Infrastructure.Repositories.PostgreSQLSecretRepository do
  @moduledoc """
  Ecto PostgreSQL implementation of the SecretRepository port.
  """
  @behaviour Thalamus.Application.Ports.SecretRepository

  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.Secret
  import Ecto.Query

  @impl true
  def create(attrs) do
    %Secret{}
    |> Secret.changeset(attrs)
    |> Repo.insert()
  end

  @impl true
  def get(id) do
    case Repo.get(Secret, id) do
      nil -> {:error, :not_found}
      secret -> {:ok, secret}
    end
  end

  @impl true
  def get_by_owner_and_provider(owner_type, owner_id, provider) do
    get_by_owner_provider_and_env(owner_type, owner_id, provider, nil)
  end

  @impl true
  def get_by_owner_provider_and_env(_owner_type, nil, _provider, _environment_id) do
    {:error, :not_found}
  end

  def get_by_owner_provider_and_env(owner_type, owner_id, provider, environment_id) do
    # 1. If environment_id is provided and is a valid UUID, try environment-specific secret first
    result =
      if environment_id && valid_uuid?(environment_id) do
        query =
          from s in Secret,
            where:
              s.owner_type == ^owner_type and s.owner_id == ^owner_id and
                s.provider == ^provider and s.environment_id == ^environment_id

        Repo.one(query)
      else
        nil
      end

    case result do
      %Secret{} = secret ->
        {:ok, secret}

      nil ->
        # 2. Fallback to global secret (where environment_id is nil)
        fallback_query =
          from s in Secret,
            where:
              s.owner_type == ^owner_type and s.owner_id == ^owner_id and
                s.provider == ^provider and is_nil(s.environment_id)

        case Repo.one(fallback_query) do
          nil -> {:error, :not_found}
          secret -> {:ok, secret}
        end
    end
  end

  @impl true
  def list_by_owner(owner_type, owner_id, environment_id \\ nil) do
    query =
      from s in Secret,
        where: s.owner_type == ^owner_type and s.owner_id == ^owner_id,
        order_by: [desc: s.inserted_at]

    query =
      if environment_id && valid_uuid?(environment_id) do
        from s in query, where: s.environment_id == ^environment_id or is_nil(s.environment_id)
      else
        query
      end

    Repo.all(query)
  end

  @impl true
  def delete(id) do
    case get(id) do
      {:ok, secret} -> Repo.delete(secret)
      error -> error
    end
  end

  defp valid_uuid?(nil), do: false

  defp valid_uuid?(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp valid_uuid?(_), do: false
end
