defmodule Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository do
  @moduledoc """
  PostgreSQL implementation of OrganizationRepository port.

  Handles persistence and retrieval of Organization entities using Ecto
  and PostgreSQL database.

  SOLID Principles Applied:
  - Single Responsibility: Only handles organization data persistence
  - Dependency Inversion: Implements the port defined by Application layer
  - Interface Segregation: Implements only OrganizationRepository interface
  """

  @behaviour Thalamus.Application.Ports.OrganizationRepository

  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.Domain.ValueObjects.{OrganizationId, UserId, Email}
  alias Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema

  import Ecto.Query

  @doc """
  Find organization by ID.
  """
  @impl true
  def find_by_id(%OrganizationId{} = org_id) do
    org_id_string = OrganizationId.to_string(org_id)
    # Extract UUID from "org_<uuid>" format for database lookup
    org_uuid = String.replace_prefix(org_id_string, "org_", "")

    case Repo.get(OrganizationSchema, org_uuid) do
      nil ->
        {:error, :not_found}

      schema ->
        {:ok, schema_to_entity(schema)}
    end
  end

  @doc """
  Find all organizations where user is a member.
  """
  @impl true
  def find_by_member(%UserId{} = user_id) do
    user_id_string = UserId.to_string(user_id)

    # Query organizations where user_id appears in the members JSONB array
    query =
      from o in OrganizationSchema,
        where: fragment("? @> ?::jsonb", o.members, ^~s([{"user_id":"#{user_id_string}"}]))

    organizations =
      query
      |> Repo.all()
      |> Enum.map(&schema_to_entity/1)

    {:ok, organizations}
  rescue
    error ->
      {:error, error}
  end

  @doc """
  Find organization by user ID (using the organization_id FK in users table).
  This returns the primary organization the user belongs to.
  """
  def find_by_user_id(%UserId{} = user_id) do
    alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

    user_id_string = UserId.to_string(user_id)

    # Query the user to get their organization_id
    query =
      from u in UserSchema,
        where: u.id == ^user_id_string,
        select: u.organization_id

    case Repo.one(query) do
      nil ->
        # User not found or no organization
        {:error, :not_found}

      org_id_string when is_binary(org_id_string) ->
        # User has an organization, fetch it
        case Repo.get(OrganizationSchema, org_id_string) do
          nil -> {:error, :not_found}
          schema -> {:ok, schema_to_entity(schema)}
        end

      _ ->
        # organization_id is nil
        {:error, :not_found}
    end
  rescue
    error ->
      {:error, error}
  end

  @doc """
  Save organization (insert or update).
  """
  @impl true
  def save(%Organization{} = organization) do
    org_id_string = OrganizationId.to_string(organization.id)
    # Extract UUID from "org_<uuid>" format for database lookup
    org_uuid = String.replace_prefix(org_id_string, "org_", "")

    # Check if organization exists
    existing = Repo.get(OrganizationSchema, org_uuid)

    changeset =
      if existing do
        # Update
        OrganizationSchema.update_changeset(existing, entity_to_map(organization))
      else
        # Insert
        OrganizationSchema.create_changeset(entity_to_map(organization))
      end

    case Repo.insert_or_update(changeset) do
      {:ok, schema} ->
        {:ok, schema_to_entity(schema)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Delete organization by ID (soft delete by marking as deactivated).
  """
  @impl true
  def delete(%OrganizationId{} = org_id) do
    org_id_string = OrganizationId.to_string(org_id)
    # Extract UUID from "org_<uuid>" format for database lookup
    org_uuid = String.replace_prefix(org_id_string, "org_", "")

    case Repo.get(OrganizationSchema, org_uuid) do
      nil ->
        {:error, :not_found}

      schema ->
        # Soft delete by setting status to inactive
        changeset = OrganizationSchema.update_changeset(schema, %{status: :cancelled})

        case Repo.update(changeset) do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  List organizations with optional filters.

  ## Filters
  - :status - Filter by status
  - :plan_type - Filter by plan type
  - :verified - Filter by verification status (boolean)
  - :limit - Maximum number of results
  - :offset - Number of results to skip
  """
  @impl true
  def list(filters \\ []) do
    query = from(o in OrganizationSchema)

    query =
      Enum.reduce(filters, query, fn
        {:status, status}, q ->
          where(q, [o], o.status == ^status)

        {:plan_type, plan_type}, q ->
          where(q, [o], o.plan_type == ^plan_type)

        {:verified, verified}, q when is_boolean(verified) ->
          where(q, [o], o.verified == ^verified)

        {:limit, limit}, q ->
          limit(q, ^limit)

        {:offset, offset}, q ->
          offset(q, ^offset)

        _, q ->
          q
      end)

    organizations =
      query
      |> Repo.all()
      |> Enum.map(&schema_to_entity/1)

    {:ok, organizations}
  rescue
    error ->
      {:error, error}
  end

  @doc """
  Count total number of organizations.
  """
  @impl true
  def count do
    count = Repo.aggregate(OrganizationSchema, :count, :id)
    {:ok, count}
  rescue
    error ->
      {:error, error}
  end

  # Private conversion functions

  defp schema_to_entity(%OrganizationSchema{} = schema) do
    {:ok, org_id} = OrganizationId.from_string(schema.id)

    # Convert members from JSONB to Member value objects
    members =
      Enum.map(schema.members, fn member_data ->
        {:ok, user_id} = UserId.from_string(member_data["user_id"])
        {:ok, email} = Email.new(member_data["email"])

        %Organization.Member{
          user_id: user_id,
          email: email,
          role: String.to_existing_atom(member_data["role"]),
          joined_at: parse_datetime(member_data["joined_at"])
        }
      end)

    # Extract owner email from members (owner is the first member with owner role)
    owner_member = Enum.find(members, fn m -> m.role == :owner end)

    owner_email_str =
      schema.owner_email || if owner_member, do: Email.to_string(owner_member.email), else: nil

    owner_email_str = if owner_email_str in [nil, ""], do: nil, else: owner_email_str

    owner_email =
      case owner_email_str do
        nil ->
          nil

        str ->
          case Email.new(str) do
            {:ok, email} -> email
            _ -> nil
          end
      end

    # Use verified boolean to determine verified_at (if verified, use inserted_at as proxy)
    verified_at = if schema.verified, do: schema.inserted_at, else: nil

    %Organization{
      id: org_id,
      name: schema.name,
      owner_email: owner_email,
      status: schema.status,
      verified_at: verified_at,
      plan_type: schema.plan_type,
      max_users: if(schema.max_users == 999_999_999, do: nil, else: schema.max_users),
      max_api_calls_per_month:
        if(schema.max_api_calls_per_month == 999_999_999,
          do: nil,
          else: schema.max_api_calls_per_month
        ),
      api_calls_current_month: schema.api_calls_current_month,
      members: members,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp entity_to_map(%Organization{} = org) do
    owner_email_str = if org.owner_email, do: Email.to_string(org.owner_email), else: nil
    org_id_string = OrganizationId.to_string(org.id)
    # Extract UUID from "org_<uuid>" format for database storage
    org_uuid = String.replace_prefix(org_id_string, "org_", "")

    %{
      id: org_uuid,
      name: org.name,
      status: org.status,
      verified: not is_nil(org.verified_at),
      plan_type: org.plan_type,
      owner_email: owner_email_str,
      max_users: org.max_users || 999_999_999,
      max_api_calls_per_month: org.max_api_calls_per_month || 999_999_999,
      api_calls_current_month: org.api_calls_current_month,
      members: Enum.map(org.members, &member_to_map/1)
    }
  end

  defp member_to_map(%Organization.Member{} = member) do
    %{
      "user_id" => UserId.to_string(member.user_id),
      "email" => Email.to_string(member.email),
      "role" => to_string(member.role),
      "joined_at" => DateTime.to_iso8601(member.joined_at)
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(%DateTime{} = datetime), do: datetime
end
