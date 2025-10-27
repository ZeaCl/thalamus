defmodule Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepository do
  @moduledoc """
  PostgreSQL implementation of the OAuth2ClientRepository port.

  This adapter converts between OAuth2Client domain entities and database schemas.
  It implements the OAuth2ClientRepository behaviour defined in the Application layer.

  SOLID Principles Applied:
  - Single Responsibility: Only handles OAuth2Client persistence
  - Dependency Inversion: Implements the port defined by Application layer
  - Interface Segregation: Implements only OAuth2ClientRepository interface
  """

  @behaviour Thalamus.Application.Ports.OAuth2ClientRepository

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema
  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{ClientId, GrantType, OrganizationId}

  @impl true
  def find_by_id(%ClientId{} = client_id) do
    client_id
    |> ClientId.to_string()
    |> do_find_by_id()
    |> case do
      nil -> {:error, :not_found}
      schema -> schema_to_entity(schema)
    end
  end

  @impl true
  def find_by_client_id(client_id_string) when is_binary(client_id_string) do
    OAuth2ClientSchema
    |> where([c], c.client_id_string == ^client_id_string)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> schema_to_entity(schema)
    end
  end

  @impl true
  def save(%OAuth2Client{} = client) do
    client
    |> entity_to_schema()
    |> case do
      %OAuth2ClientSchema{id: nil} = schema ->
        # New client - insert
        schema_map = Map.from_struct(schema)
        OAuth2ClientSchema.create_changeset(schema_map)
        |> Repo.insert()

      %OAuth2ClientSchema{} = schema ->
        # Existing client - update
        existing = Repo.get!(OAuth2ClientSchema, schema.id)

        existing
        |> OAuth2ClientSchema.update_changeset(Map.from_struct(schema))
        |> Repo.update()
    end
    |> case do
      {:ok, saved_schema} -> schema_to_entity(saved_schema)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete(%ClientId{} = client_id) do
    client_id_string = ClientId.to_string(client_id)

    case Repo.get(OAuth2ClientSchema, client_id_string) do
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
  def find_by_organization(%OrganizationId{} = org_id) do
    org_id_string = OrganizationId.to_string(org_id)

    OAuth2ClientSchema
    |> where([c], c.organization_id == ^org_id_string)
    |> Repo.all()
    |> Enum.map(fn schema ->
      case schema_to_entity(schema) do
        {:ok, entity} -> entity
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> then(&{:ok, &1})
  end

  @impl true
  def count_by_organization(%OrganizationId{} = org_id) do
    org_id_string = OrganizationId.to_string(org_id)

    count =
      OAuth2ClientSchema
      |> where([c], c.organization_id == ^org_id_string)
      |> Repo.aggregate(:count, :id)

    {:ok, count}
  end

  # Private conversion functions

  defp do_find_by_id(client_id_string) do
    Repo.get(OAuth2ClientSchema, client_id_string)
  end

  defp schema_to_entity(%OAuth2ClientSchema{} = schema) do
    with {:ok, client_id} <- ClientId.from_string(schema.id),
         {:ok, grant_types} <- convert_grant_types_from_db(schema.allowed_grant_types) do
      client = %OAuth2Client{
        id: client_id,
        name: schema.name,
        client_type: schema.client_type,
        client_secret: schema.client_secret,
        grant_types: grant_types,
        allowed_scopes: schema.allowed_scopes || [],
        redirect_uris: schema.redirect_uris || [],
        is_active: schema.is_active,
        trusted: false,
        created_at: schema.inserted_at,
        updated_at: schema.updated_at
      }

      {:ok, client}
    end
  end

  defp entity_to_schema(%OAuth2Client{} = client) do
    grant_types_strings = convert_grant_types_to_db(client.grant_types)

    %OAuth2ClientSchema{
      id: if(client.id, do: ClientId.to_string(client.id), else: nil),
      client_id_string: if(client.id, do: ClientId.to_string(client.id), else: nil),
      name: client.name,
      client_type: client.client_type,
      client_secret: client.client_secret,
      allowed_grant_types: grant_types_strings,
      allowed_scopes: client.allowed_scopes,
      redirect_uris: client.redirect_uris,
      is_active: client.is_active,
      inserted_at: client.created_at,
      updated_at: client.updated_at
    }
  end

  defp convert_grant_types_from_db(grant_type_strings) when is_list(grant_type_strings) do
    grant_types =
      Enum.map(grant_type_strings, fn type_string ->
        type_atom = String.to_existing_atom(type_string)

        case GrantType.new(type_atom) do
          {:ok, grant_type} -> grant_type
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, grant_types}
  end

  defp convert_grant_types_from_db(_), do: {:ok, []}

  defp convert_grant_types_to_db(grant_types) when is_list(grant_types) do
    Enum.map(grant_types, fn %GrantType{} = grant_type ->
      to_string(grant_type.type)
    end)
  end

  defp convert_grant_types_to_db(_), do: []

  defp build_query(filters) do
    query = from(c in OAuth2ClientSchema)

    query
    |> filter_by_active(filters[:is_active])
    |> filter_by_client_type(filters[:client_type])
    |> filter_by_organization(filters[:organization_id])
    |> order_by_field(filters[:order_by])
    |> limit_results(filters[:limit])
    |> offset_results(filters[:offset])
  end

  defp filter_by_active(query, nil), do: query
  defp filter_by_active(query, is_active) when is_boolean(is_active) do
    where(query, [c], c.is_active == ^is_active)
  end

  defp filter_by_client_type(query, nil), do: query
  defp filter_by_client_type(query, client_type) when is_atom(client_type) do
    where(query, [c], c.client_type == ^client_type)
  end

  defp filter_by_organization(query, nil), do: query
  defp filter_by_organization(query, org_id) when is_binary(org_id) do
    where(query, [c], c.organization_id == ^org_id)
  end

  defp order_by_field(query, nil), do: order_by(query, [c], desc: c.inserted_at)
  defp order_by_field(query, :name), do: order_by(query, [c], asc: c.name)
  defp order_by_field(query, :created_at), do: order_by(query, [c], desc: c.inserted_at)
  defp order_by_field(query, _), do: query

  defp limit_results(query, nil), do: query
  defp limit_results(query, limit) when is_integer(limit), do: limit(query, ^limit)

  defp offset_results(query, nil), do: query
  defp offset_results(query, offset) when is_integer(offset), do: offset(query, ^offset)
end
