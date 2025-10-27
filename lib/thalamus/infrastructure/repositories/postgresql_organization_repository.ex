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

    case Repo.get(OrganizationSchema, org_id_string) do
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
  Save organization (insert or update).
  """
  @impl true
  def save(%Organization{} = organization) do
    org_id_string = OrganizationId.to_string(organization.id)

    # Check if organization exists
    existing = Repo.get(OrganizationSchema, org_id_string)

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

    case Repo.get(OrganizationSchema, org_id_string) do
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

        {:verified, true}, q ->
          where(q, [o], not is_nil(o.verified_at))

        {:verified, false}, q ->
          where(q, [o], is_nil(o.verified_at))

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
    {:ok, owner_email} = Email.new(schema.owner_email)

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

    %Organization{
      id: org_id,
      name: schema.name,
      owner_email: owner_email,
      status: schema.status,
      verified_at: schema.verified_at,
      plan_type: schema.plan_type,
      max_users: schema.max_users,
      max_api_calls_per_month: schema.max_api_calls_per_month,
      api_calls_current_month: schema.api_calls_current_month,
      members: members,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp entity_to_map(%Organization{} = org) do
    %{
      id: OrganizationId.to_string(org.id),
      name: org.name,
      owner_email: Email.to_string(org.owner_email),
      status: org.status,
      verified_at: org.verified_at,
      plan_type: org.plan_type,
      max_users: org.max_users,
      max_api_calls_per_month: org.max_api_calls_per_month,
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
