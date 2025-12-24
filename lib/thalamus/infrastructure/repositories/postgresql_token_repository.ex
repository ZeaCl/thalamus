defmodule Thalamus.Infrastructure.Repositories.PostgreSQLTokenRepository do
  @moduledoc """
  PostgreSQL implementation of the TokenRepository port.

  This adapter handles OAuth2 token storage and retrieval.
  It implements the TokenRepository behaviour defined in the Application layer.

  SOLID Principles Applied:
  - Single Responsibility: Only handles token persistence
  - Dependency Inversion: Implements the port defined by Application layer
  - Interface Segregation: Implements only TokenRepository interface
  """

  @behaviour Thalamus.Application.Ports.TokenRepository

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.TokenSchema
  alias Thalamus.Domain.ValueObjects.{UserId, ClientId}

  @impl true
  def store(token_data) when is_map(token_data) do
    attrs = prepare_token_attrs(token_data)

    case TokenSchema.create_changeset(attrs) do
      changeset when changeset.valid? ->
        case Repo.insert(changeset) do
          {:ok, _schema} -> :ok
          {:error, reason} -> {:error, reason}
        end

      changeset ->
        {:error, changeset}
    end
  end

  @impl true
  def find(token) when is_binary(token) do
    TokenSchema
    |> where([t], t.token == ^token)
    |> where([t], t.revoked == false)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_token_data(schema)}
    end
  end

  @impl true
  def revoke(token) when is_binary(token) do
    TokenSchema
    |> where([t], t.token == ^token)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> TokenSchema.revoke_changeset()
        |> Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @impl true
  def revoke_all_for_user(%UserId{} = user_id) do
    user_id_string = UserId.to_string(user_id)

    TokenSchema
    |> where([t], t.user_id == ^user_id_string)
    |> where([t], t.revoked == false)
    |> Repo.update_all(set: [revoked: true, revoked_at: DateTime.utc_now()])
    |> case do
      {_count, _} -> :ok
    end
  end

  @impl true
  def revoke_all_for_client(%ClientId{} = client_id) do
    client_id_string = ClientId.to_string(client_id)

    TokenSchema
    |> where([t], t.client_id == ^client_id_string)
    |> where([t], t.revoked == false)
    |> Repo.update_all(set: [revoked: true, revoked_at: DateTime.utc_now()])
    |> case do
      {_count, _} -> :ok
    end
  end

  @impl true
  def cleanup_expired do
    now = DateTime.utc_now()

    TokenSchema
    |> where([t], t.expires_at < ^now)
    |> Repo.delete_all()
    |> case do
      {count, _} -> {:ok, count}
    end
  end

  @impl true
  def find_by_user(%UserId{} = user_id) do
    user_id_string = UserId.to_string(user_id)

    TokenSchema
    |> where([t], t.user_id == ^user_id_string)
    |> where([t], t.revoked == false)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
    |> Enum.map(&schema_to_token_data/1)
    |> then(&{:ok, &1})
  end

  # Private helper functions

  defp prepare_token_attrs(token_data) do
    %{
      token: token_data.token,
      type: token_data.type,
      user_id: prepare_user_id(token_data.user_id),
      client_id: prepare_client_id(token_data.client_id),
      organization_id: prepare_organization_id(Map.get(token_data, :organization_id)),
      scopes: token_data.scopes || [],
      expires_at: token_data.expires_at,
      code_challenge: Map.get(token_data, :code_challenge),
      code_challenge_method: Map.get(token_data, :code_challenge_method),
      token_family_id: Map.get(token_data, :token_family_id)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp prepare_user_id(nil), do: nil
  defp prepare_user_id(%UserId{} = user_id) do
    # Extract UUID without "user_" prefix for DB storage
    user_id_string = UserId.to_string(user_id)
    String.replace_prefix(user_id_string, "user_", "")
  end
  defp prepare_user_id(user_id) when is_binary(user_id) do
    # If already a string, check if it has the prefix and remove it
    String.replace_prefix(user_id, "user_", "")
  end

  defp prepare_client_id(%ClientId{} = client_id), do: ClientId.to_string(client_id)
  defp prepare_client_id(client_id) when is_binary(client_id), do: client_id

  defp prepare_organization_id(nil), do: nil
  defp prepare_organization_id(%Thalamus.Domain.ValueObjects.OrganizationId{} = org_id) do
    Thalamus.Domain.ValueObjects.OrganizationId.to_string(org_id)
  end
  defp prepare_organization_id(org_id) when is_binary(org_id), do: org_id

  defp schema_to_token_data(%TokenSchema{} = schema) do
    alias Thalamus.Domain.ValueObjects.OrganizationId

    # Reconstruct the user_id as UserId value object if present
    user_id =
      if schema.user_id do
        case UserId.from_string(schema.user_id) do
          {:ok, user_id} -> user_id
          _ -> nil
        end
      else
        nil
      end

    # Reconstruct the client_id as ClientId value object
    client_id =
      case ClientId.from_string(schema.client_id) do
        {:ok, client_id} -> client_id
        _ -> nil
      end

    # Reconstruct the organization_id as OrganizationId value object if present
    organization_id =
      if schema.organization_id do
        case OrganizationId.from_string(schema.organization_id) do
          {:ok, org_id} -> org_id
          _ -> nil
        end
      else
        nil
      end

    %{
      token: schema.token,
      type: schema.type,
      user_id: user_id,
      client_id: client_id,
      organization_id: organization_id,
      scopes: schema.scopes || [],
      expires_at: schema.expires_at,
      revoked: schema.revoked,
      created_at: schema.inserted_at
    }
  end
end
