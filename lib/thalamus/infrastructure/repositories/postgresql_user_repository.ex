defmodule Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository do
  @moduledoc """
  PostgreSQL implementation of the UserRepository port.

  This adapter converts between domain entities and database schemas.
  It implements the UserRepository behaviour defined in the Application layer.

  SOLID Principles Applied:
  - Single Responsibility: Only handles User persistence
  - Dependency Inversion: Implements the port defined by Application layer
  - Interface Segregation: Implements only UserRepository interface
  """

  @behaviour Thalamus.Application.Ports.UserRepository

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema
  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash, MFAMethod}

  @impl true
  def find_by_id(user_id) do
    user_id
    |> to_string()
    |> do_find_by_id()
    |> case do
      nil -> {:error, :not_found}
      schema -> schema_to_entity(schema)
    end
  end

  @impl true
  def find_by_email(%Email{} = email) do
    email_string = Email.to_string(email)

    UserSchema
    |> where([u], u.email == ^email_string)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> schema_to_entity(schema)
    end
  end

  @impl true
  def save(%User{} = user) do
    user
    |> entity_to_schema()
    |> case do
      %UserSchema{id: nil} = schema ->
        # New user - insert
        schema_map = Map.from_struct(schema)
        UserSchema.create_changeset(schema_map)
        |> Repo.insert()

      %UserSchema{} = schema ->
        # Existing user - update
        existing = Repo.get!(UserSchema, schema.id)

        existing
        |> UserSchema.update_changeset(Map.from_struct(schema))
        |> Repo.update()
    end
    |> case do
      {:ok, saved_schema} -> schema_to_entity(saved_schema)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete(%UserId{} = user_id) do
    user_id_string = UserId.to_string(user_id)

    case Repo.get(UserSchema, user_id_string) do
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
        case schema_to_entity(schema) do
          {:ok, entity} -> entity
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, entities}
  end

  @impl true
  def count(filters \\ %{}) do
    query = build_query(filters)

    count = Repo.aggregate(query, :count, :id)

    {:ok, count}
  end

  @impl true
  def update_last_login(%UserId{} = user_id, timestamp) do
    user_id_string = UserId.to_string(user_id)

    case Repo.get(UserSchema, user_id_string) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> Ecto.Changeset.change(%{last_login_at: timestamp})
        |> Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  # Private conversion functions

  defp do_find_by_id(user_id_string) do
    Repo.get(UserSchema, user_id_string)
  end

  defp schema_to_entity(%UserSchema{} = schema) do
    with {:ok, user_id} <- UserId.from_string(schema.id),
         {:ok, email} <- Email.new(schema.email),
         {:ok, password_hash} <- PasswordHash.from_hash(schema.password_hash),
         {:ok, mfa_methods} <- convert_mfa_methods_from_db(schema.mfa_methods) do
      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: schema.status,
        verified_at: schema.verified_at,
        last_login_at: schema.last_login_at,
        failed_login_attempts: schema.failed_login_attempts,
        locked_until: schema.locked_until,
        mfa_methods: mfa_methods,
        created_at: schema.inserted_at,
        updated_at: schema.updated_at
      }

      {:ok, user}
    end
  end

  defp entity_to_schema(%User{} = user) do
    mfa_methods_maps = convert_mfa_methods_to_db(user.mfa_methods)

    %UserSchema{
      id: if(user.id, do: UserId.to_string(user.id), else: nil),
      email: Email.to_string(user.email),
      password_hash: PasswordHash.to_string(user.password_hash),
      status: user.status,
      verified_at: user.verified_at,
      last_login_at: user.last_login_at,
      failed_login_attempts: user.failed_login_attempts,
      locked_until: user.locked_until,
      mfa_methods: mfa_methods_maps,
      inserted_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  defp convert_mfa_methods_from_db(mfa_methods_maps) when is_list(mfa_methods_maps) do
    mfa_methods =
      Enum.map(mfa_methods_maps, fn map ->
        type = String.to_existing_atom(map["type"])
        identifier = map["identifier"]
        verified = map["verified"]

        case MFAMethod.new(type, identifier, verified) do
          {:ok, mfa_method} -> mfa_method
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, mfa_methods}
  end

  defp convert_mfa_methods_from_db(_), do: {:ok, []}

  defp convert_mfa_methods_to_db(mfa_methods) when is_list(mfa_methods) do
    Enum.map(mfa_methods, fn %MFAMethod{} = method ->
      %{
        "type" => to_string(method.type),
        "identifier" => method.identifier,
        "verified" => method.verified,
        "created_at" => DateTime.to_iso8601(method.created_at)
      }
    end)
  end

  defp convert_mfa_methods_to_db(_), do: []

  defp build_query(filters) do
    query = from(u in UserSchema)

    query
    |> filter_by_status(filters[:status])
    |> filter_by_verified(filters[:verified])
    |> filter_by_organization(filters[:organization_id])
    |> order_by_field(filters[:order_by])
    |> limit_results(filters[:limit])
    |> offset_results(filters[:offset])
  end

  defp filter_by_status(query, nil), do: query

  defp filter_by_status(query, status) when is_atom(status) do
    where(query, [u], u.status == ^status)
  end

  defp filter_by_verified(query, nil), do: query

  defp filter_by_verified(query, true) do
    where(query, [u], not is_nil(u.verified_at))
  end

  defp filter_by_verified(query, false) do
    where(query, [u], is_nil(u.verified_at))
  end

  defp filter_by_organization(query, nil), do: query

  defp filter_by_organization(query, org_id) when is_binary(org_id) do
    where(query, [u], u.organization_id == ^org_id)
  end

  defp order_by_field(query, nil), do: order_by(query, [u], desc: u.inserted_at)
  defp order_by_field(query, :email), do: order_by(query, [u], asc: u.email)
  defp order_by_field(query, :created_at), do: order_by(query, [u], desc: u.inserted_at)
  defp order_by_field(query, :last_login), do: order_by(query, [u], desc: u.last_login_at)
  defp order_by_field(query, _), do: query

  defp limit_results(query, nil), do: query
  defp limit_results(query, limit) when is_integer(limit), do: limit(query, ^limit)

  defp offset_results(query, nil), do: query
  defp offset_results(query, offset) when is_integer(offset), do: offset(query, ^offset)
end
