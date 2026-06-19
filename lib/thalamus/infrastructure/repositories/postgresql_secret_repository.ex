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
  def get_by_owner_and_provider(_owner_type, nil, _provider) do
    {:error, :not_found}
  end

  def get_by_owner_and_provider(owner_type, owner_id, provider) do
    query = from s in Secret,
      where: s.owner_type == ^owner_type and s.owner_id == ^owner_id and s.provider == ^provider

    case Repo.one(query) do
      nil -> {:error, :not_found}
      secret -> {:ok, secret}
    end
  end

  @impl true
  def list_by_owner(owner_type, owner_id) do
    query = from s in Secret,
      where: s.owner_type == ^owner_type and s.owner_id == ^owner_id,
      order_by: [desc: s.inserted_at]

    Repo.all(query)
  end

  @impl true
  def delete(id) do
    case get(id) do
      {:ok, secret} -> Repo.delete(secret)
      error -> error
    end
  end
end
