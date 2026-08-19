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
      {:error, :invalid_uuid} -> {:error, :invalid_uuid}
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
  def find_by_ids([]), do: {:ok, %{}}

  def find_by_ids(user_ids) when is_list(user_ids) do
    users_map =
      UserSchema
      |> where([u], u.id in ^user_ids)
      |> Repo.all()
      |> build_users_map()

    {:ok, users_map}
  end

  defp build_users_map(schemas) do
    Enum.reduce(schemas, %{}, &add_user_to_map/2)
  end

  defp add_user_to_map(schema, acc) do
    case schema_to_entity(schema) do
      {:ok, user} -> Map.put(acc, schema.id, user)
      {:error, _} -> acc
    end
  end

  @impl true
  def save(%User{} = user) do
    schema = entity_to_schema(user)

    # Check if user exists in database (by looking up the UUID)
    existing = if schema.id, do: Repo.get(UserSchema, schema.id), else: nil

    result =
      case existing do
        nil ->
          # New user - insert
          schema_map = Map.from_struct(schema)

          UserSchema.create_changeset(schema_map)
          |> Repo.insert()

        existing_schema ->
          # Existing user - update
          existing_schema
          |> UserSchema.update_changeset(Map.from_struct(schema))
          |> Repo.update()
      end

    case result do
      {:ok, saved_schema} -> schema_to_entity(saved_schema)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete(%UserId{} = user_id) do
    user_id_string = UserId.to_string(user_id)
    # Extract UUID from "user_<uuid>" format
    uuid = String.replace_prefix(user_id_string, "user_", "")

    case Repo.get(UserSchema, uuid) do
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
    uuid = String.replace_prefix(user_id_string, "user_", "")

    case Repo.get(UserSchema, uuid) do
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

  @impl true
  def find_by_parent(%UserId{} = user_id) do
    parent_uuid = user_id |> to_string() |> extract_uuid()

    if parent_uuid do
      children =
        UserSchema
        |> where([u], u.parent_user_id == ^parent_uuid)
        |> order_by([u], asc: u.name)
        |> Repo.all()
        |> Enum.flat_map(&schema_to_entity_list/1)

      {:ok, children}
    else
      {:ok, []}
    end
  end

  @impl true
  def find_tree(%UserId{} = user_id, opts \\ []) do
    organization_id = Keyword.get(opts, :organization_id)

    case find_by_parent(user_id) do
      {:ok, []} -> {:ok, []}
      {:ok, first_level} -> collect_subtree(first_level, organization_id, MapSet.new())
      error -> error
    end
  end

  @impl true
  def find_agents_subtree(%UserId{} = user_id) do
    with {:ok, tree} <- find_tree(user_id) do
      agents = Enum.filter(tree, & &1.is_agent)
      {:ok, agents}
    end
  end

  # Private conversion functions

  defp do_find_by_id(user_id_string) do
    # Extract UUID from "user_<uuid>" format
    uuid = String.replace_prefix(user_id_string, "user_", "")

    case Ecto.UUID.cast(uuid) do
      {:ok, valid_uuid} -> Repo.get(UserSchema, valid_uuid)
      :error -> nil
    end
  end

  defp extract_uuid(%UserId{} = user_id), do: extract_uuid(to_string(user_id))

  defp extract_uuid(user_id_string) when is_binary(user_id_string) do
    case String.replace_prefix(user_id_string, "user_", "") do
      "" -> nil
      uuid -> uuid
    end
  end

  defp extract_uuid(_), do: nil

  defp schema_to_entity_list(%UserSchema{} = schema) do
    case schema_to_entity(schema) do
      {:ok, entity} -> [entity]
      {:error, _} -> []
    end
  end

  # BFS traversal of the hierarchy below +first_level+, collecting all descendants
  # while guarding against cycles and optionally constraining to an organization.
  defp collect_subtree(first_level, organization_id, _seen) do
    do_collect_subtree(first_level, organization_id, MapSet.new(), [])
  end

  defp do_collect_subtree(nodes, organization_id, seen, acc) do
    ids = Enum.map(nodes, fn node -> node.id |> to_string() |> extract_uuid() end)

    next_level =
      UserSchema
      |> where([u], u.parent_user_id in ^ids)
      |> order_by([u], asc: u.name)
      |> Repo.all()
      |> Enum.flat_map(&schema_to_entity_list/1)
      |> Enum.reject(fn node -> MapSet.member?(seen, to_string(node.id)) end)
      |> maybe_filter_org(organization_id)

    new_seen = Enum.reduce(nodes, seen, fn node, s -> MapSet.put(s, to_string(node.id)) end)
    acc = acc ++ nodes

    case next_level do
      [] -> {:ok, acc}
      _ -> do_collect_subtree(next_level, organization_id, new_seen, acc)
    end
  end

  defp maybe_filter_org(nodes, nil), do: nodes

  defp maybe_filter_org(nodes, org_id) do
    normalized = String.replace_prefix(to_string(org_id), "org_", "")

    Enum.filter(nodes, fn node ->
      case node.organization_id do
        nil -> false
        org -> String.replace_prefix(to_string(org), "org_", "") == normalized
      end
    end)
  end

  defp schema_to_entity(%UserSchema{} = schema) do
    # Reconstruct UserId with "user_" prefix (DB stores just UUID)
    user_id_string = "user_" <> schema.id

    with {:ok, user_id} <- UserId.from_string(user_id_string),
         {:ok, email} <- Email.new(schema.email),
         {:ok, password_hash} <- PasswordHash.from_hash(schema.password_hash),
         {:ok, mfa_methods} <- convert_mfa_methods_from_db(schema.mfa_methods) do
      user = %User{
        id: user_id,
        organization_id:
          if(schema.organization_id, do: "org_" <> schema.organization_id, else: nil),
        parent_user_id:
          if(schema.parent_user_id, do: "user_" <> schema.parent_user_id, else: nil),
        email: email,
        name: schema.name,
        avatar_url: schema.avatar_url,
        password_hash: password_hash,
        status: schema.status,
        email_verified: schema.verified_at != nil,
        verified_at: schema.verified_at,
        last_login_at: schema.last_login_at,
        failed_login_attempts: schema.failed_login_attempts,
        locked_until: schema.locked_until,
        mfa_methods: mfa_methods,
        created_at: schema.inserted_at,
        updated_at: schema.updated_at,
        is_agent: schema.is_agent,
        agent_config: schema.agent_config
      }

      {:ok, user}
    end
  end

  defp entity_to_schema(%User{} = user) do
    mfa_methods_maps = convert_mfa_methods_to_db(user.mfa_methods)

    # Extract UUID from UserId (removes "user_" prefix)
    # UserId.to_string returns "user_<uuid>", but DB expects just "<uuid>"
    user_uuid =
      if user.id do
        user_id_string = UserId.to_string(user.id)
        String.replace_prefix(user_id_string, "user_", "")
      else
        nil
      end

    org_uuid =
      case user.organization_id do
        nil -> nil
        %{value: val} -> String.replace_prefix(val, "org_", "")
        val when is_binary(val) -> String.replace_prefix(val, "org_", "")
      end

    parent_uuid =
      case user.parent_user_id do
        nil -> nil
        val when is_binary(val) -> String.replace_prefix(val, "user_", "")
      end

    %UserSchema{
      id: user_uuid,
      email: Email.to_string(user.email),
      name: user.name,
      avatar_url: user.avatar_url,
      password_hash: PasswordHash.to_string(user.password_hash),
      status: user.status,
      organization_id: org_uuid,
      parent_user_id: parent_uuid,
      verified_at: user.verified_at,
      last_login_at: user.last_login_at,
      failed_login_attempts: user.failed_login_attempts,
      locked_until: user.locked_until,
      mfa_methods: mfa_methods_maps,
      inserted_at: user.created_at,
      updated_at: user.updated_at,
      is_agent: user.is_agent,
      agent_config: user.agent_config
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
    |> filter_by_username(filters[:username])
    |> filter_by_is_agent(filters[:is_agent])
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

  defp filter_by_username(query, nil), do: query

  defp filter_by_username(query, username) when is_binary(username) and username != "" do
    search_term = "%#{username}%"

    where(query, [u], ilike(u.name, ^search_term) or ilike(u.email, ^search_term))
  end

  defp filter_by_username(query, _), do: query

  defp filter_by_is_agent(query, nil), do: query

  defp filter_by_is_agent(query, true) do
    where(query, [u], u.is_agent == true)
  end

  defp filter_by_is_agent(query, false) do
    where(query, [u], u.is_agent == false or is_nil(u.is_agent))
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
