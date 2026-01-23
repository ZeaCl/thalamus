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
  alias Thalamus.Domain.ValueObjects.{ClientId, GrantType, OrganizationId, Scope, RedirectUri}

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
    # Remove "client_" prefix if present (OAuth endpoints send with prefix, DB stores without)
    uuid_only = String.replace_prefix(client_id_string, "client_", "")

    OAuth2ClientSchema
    |> where([c], c.client_id_string == ^uuid_only)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> schema_to_entity(schema)
    end
  end

  @impl true
  def save(%OAuth2Client{} = client) do
    schema = entity_to_schema(client)

    # Check if client exists in database (by looking up the UUID)
    existing = if schema.id, do: Repo.get(OAuth2ClientSchema, schema.id), else: nil

    result =
      case existing do
        nil ->
          # New client - insert
          schema_map = Map.from_struct(schema)

          OAuth2ClientSchema.create_changeset(schema_map)
          |> Repo.insert()

        existing_schema ->
          # Existing client - update
          schema_map = Map.from_struct(schema)

          # Check if client_secret has changed - if so, use rotate_secret_changeset
          changeset =
            if schema_map[:client_secret] &&
                 schema_map[:client_secret] != existing_schema.client_secret do
              # Secret has changed - use rotate_secret_changeset and update other fields
              existing_schema
              |> OAuth2ClientSchema.rotate_secret_changeset(schema_map[:client_secret])
              |> Ecto.Changeset.change(
                Map.take(schema_map, [
                  :name,
                  :description,
                  :logo_url,
                  :terms_of_service_url,
                  :privacy_policy_url,
                  :is_active,
                  :pkce_required,
                  :allowed_grant_types,
                  :allowed_scopes,
                  :redirect_uris,
                  :access_token_lifetime,
                  :refresh_token_lifetime
                ])
              )
            else
              # Normal update
              existing_schema
              |> OAuth2ClientSchema.update_changeset(schema_map)
            end

          Repo.update(changeset)
      end

    case result do
      {:ok, saved_schema} -> schema_to_entity(saved_schema)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete(%ClientId{} = client_id) do
    client_id_string = ClientId.to_string(client_id)
    # Extract UUID from "client_<uuid>" format
    uuid = String.replace_prefix(client_id_string, "client_", "")

    case Repo.get(OAuth2ClientSchema, uuid) do
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
    # Extract UUID from "client_<uuid>" format
    uuid = String.replace_prefix(client_id_string, "client_", "")
    Repo.get(OAuth2ClientSchema, uuid)
  end

  defp schema_to_entity(%OAuth2ClientSchema{} = schema) do
    # Reconstruct ClientId with "client_" prefix (DB stores just UUID)
    client_id_string = "client_" <> schema.id

    # Convert client_secret from hash string to ClientSecret value object if present
    client_secret =
      if schema.client_secret do
        Thalamus.Domain.ValueObjects.ClientSecret.from_hash(schema.client_secret)
      else
        nil
      end

    with {:ok, client_id} <- ClientId.from_string(client_id_string),
         {:ok, org_id} <- OrganizationId.from_string(schema.organization_id),
         {:ok, grant_types} <- convert_grant_types_from_db(schema.allowed_grant_types),
         {:ok, scopes} <- convert_scopes_from_db(schema.allowed_scopes),
         {:ok, redirect_uris} <- convert_redirect_uris_from_db(schema.redirect_uris) do
      client = %OAuth2Client{
        id: client_id,
        organization_id: org_id,
        name: schema.name,
        client_type: schema.client_type,
        client_secret: client_secret,
        grant_types: grant_types,
        allowed_scopes: scopes,
        redirect_uris: redirect_uris,
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
    scopes_strings = convert_scopes_to_db(client.allowed_scopes)
    redirect_uris_strings = convert_redirect_uris_to_db(client.redirect_uris)

    # Extract UUID from ClientId (removes "client_" prefix)
    # ClientId.to_string returns "client_<uuid>", but DB expects just "<uuid>"
    client_uuid =
      if client.id do
        client_id_string = ClientId.to_string(client.id)
        String.replace_prefix(client_id_string, "client_", "")
      else
        nil
      end

    # Extract organization_id string (could have "org_" prefix or be pure UUID)
    org_id_string =
      if client.organization_id do
        OrganizationId.to_string(client.organization_id)
      else
        nil
      end

    # Extract client_secret hash for database storage
    # Handle both string (plain secret) and ClientSecret value object
    client_secret_hash =
      case client.client_secret do
        nil ->
          nil

        %Thalamus.Domain.ValueObjects.ClientSecret{} = secret ->
          Thalamus.Domain.ValueObjects.ClientSecret.to_string(secret)

        secret when is_binary(secret) ->
          # Plain text secret - hash it before storing
          Bcrypt.hash_pwd_salt(secret)
      end

    %OAuth2ClientSchema{
      id: client_uuid,
      client_id_string: client_uuid,
      name: client.name,
      client_type: client.client_type,
      client_secret: client_secret_hash,
      organization_id: org_id_string,
      allowed_grant_types: grant_types_strings,
      allowed_scopes: scopes_strings,
      redirect_uris: redirect_uris_strings,
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

  defp convert_scopes_from_db(scope_strings) when is_list(scope_strings) do
    scopes =
      Enum.map(scope_strings, fn scope_string ->
        case Scope.new(scope_string) do
          {:ok, scope} -> scope
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, scopes}
  end

  defp convert_scopes_from_db(_), do: {:ok, []}

  defp convert_scopes_to_db(scopes) when is_list(scopes) do
    Enum.map(scopes, fn %Scope{} = scope ->
      Scope.to_string(scope)
    end)
  end

  defp convert_scopes_to_db(_), do: []

  defp convert_redirect_uris_from_db(uri_strings) when is_list(uri_strings) do
    uris =
      Enum.map(uri_strings, fn uri_string ->
        case RedirectUri.new(uri_string) do
          {:ok, uri} -> uri
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, uris}
  end

  defp convert_redirect_uris_from_db(_), do: {:ok, []}

  defp convert_redirect_uris_to_db(uris) when is_list(uris) do
    Enum.map(uris, fn %RedirectUri{} = uri ->
      RedirectUri.to_string(uri)
    end)
  end

  defp convert_redirect_uris_to_db(_), do: []

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
