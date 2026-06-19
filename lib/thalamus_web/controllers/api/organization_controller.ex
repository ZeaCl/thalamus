defmodule ThalamusWeb.API.OrganizationController do
  @moduledoc """
  Organization Management API Controller.

  Provides REST API for organization management operations:
  - List organizations
  - Get organization details
  - Create organization
  - Update organization
  - Delete organization (soft delete)
  - Manage organization members

  SOLID Principles Applied:
  - Single Responsibility: Only handles HTTP organization management requests
  - Dependency Inversion: Depends on repositories through interfaces
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository
  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository
  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.Domain.ValueObjects.{OrganizationId, UserId, Email}

  @doc """
  GET /api/organizations

  List all organizations with optional filtering.

  ## Query Parameters
  - status: Filter by status (pending_verification, active, suspended, inactive)
  - plan_type: Filter by plan (free, starter, professional, enterprise)
  - verified: Filter by verification status (true/false)
  - limit: Number of results (default: 50, max: 100)
  - offset: Pagination offset

  ## Response
  200 OK with array of organization objects
  """
  def index(conn, params) do
    filters = build_filters(params)

    case PostgreSQLOrganizationRepository.list(filters) do
      {:ok, organizations} ->
        conn
        |> put_status(:ok)
        |> json(%{
          data: Enum.map(organizations, &organization_to_json/1),
          meta: %{
            count: length(organizations),
            filters: filters
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to list organizations", details: inspect(reason)})
    end
  end

  @doc """
  GET /api/organizations/:id

  Get a specific organization by ID.

  ## Path Parameters
  - id: Organization UUID

  ## Response
  - 200 OK: Organization found
  - 404 Not Found: Organization not found
  """
  def show(conn, %{"id" => id}) do
    case OrganizationId.from_string(id) do
      {:ok, org_id} ->
        case PostgreSQLOrganizationRepository.find_by_id(org_id) do
          {:ok, organization} ->
            conn
            |> put_status(:ok)
            |> json(%{data: organization_to_json(organization)})

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Organization not found"})
        end

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid organization ID format"})
    end
  end

  @doc """
  POST /api/organizations

  Create a new organization.

  ## Request Body (JSON)
  {
    "name": "Acme Corporation",
    "owner_email": "owner@acme.com",
    "plan_type": "free|starter|professional|enterprise"
  }

  ## Response
  - 201 Created: Organization created successfully
  - 400 Bad Request: Invalid input
  """
  def create(conn, params) do
    with {:ok, name} <- get_required_param(params, "name"),
         {:ok, owner_email_string} <- get_required_param(params, "owner_email"),
         {:ok, organization} <- Organization.new(name, owner_email_string),
         organization <- apply_plan_type(organization, params["plan_type"]),
         {:ok, saved_org} <- PostgreSQLOrganizationRepository.save(organization) do
      conn
      |> put_status(:created)
      |> json(%{
        data: organization_to_json(saved_org),
        message: "Organization created successfully"
      })
    else
      {:error, :missing_parameter, param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{param}"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Validation failed", details: errors})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create organization", details: inspect(reason)})
    end
  end

  @doc """
  PATCH /api/organizations/:id

  Update an organization.

  ## Path Parameters
  - id: Organization UUID

  ## Request Body (JSON)
  {
    "name": "New Name",
    "status": "active|suspended|inactive",
    "plan_type": "free|starter|professional|enterprise"
  }

  ## Response
  - 200 OK: Organization updated
  - 404 Not Found: Organization not found
  - 400 Bad Request: Invalid input
  """
  def update(conn, %{"id" => id} = params) do
    with {:ok, org_id} <- OrganizationId.from_string(id),
         {:ok, organization} <- PostgreSQLOrganizationRepository.find_by_id(org_id),
         {:ok, updated_org} <- apply_updates(organization, params),
         {:ok, saved_org} <- PostgreSQLOrganizationRepository.save(updated_org) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: organization_to_json(saved_org),
        message: "Organization updated successfully"
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Organization not found"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to update organization", details: inspect(reason)})
    end
  end

  @doc """
  DELETE /api/organizations/:id

  Delete an organization (soft delete by deactivating).

  ## Path Parameters
  - id: Organization UUID

  ## Response
  - 204 No Content: Organization deleted
  - 404 Not Found: Organization not found
  """
  def delete(conn, %{"id" => id}) do
    with {:ok, org_id} <- OrganizationId.from_string(id),
         :ok <- PostgreSQLOrganizationRepository.delete(org_id) do
      conn
      |> put_status(:no_content)
      |> json(%{})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Organization not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to delete organization", details: inspect(reason)})
    end
  end

  # Private helper functions

  defp build_filters(params) do
    filters = %{}

    filters =
      if status = params["status"] do
        Map.put(filters, :status, String.to_existing_atom(status))
      else
        filters
      end

    filters =
      if plan_type = params["plan_type"] do
        Map.put(filters, :plan_type, String.to_existing_atom(plan_type))
      else
        filters
      end

    filters =
      if verified = params["verified"] do
        Map.put(filters, :verified, verified == "true")
      else
        filters
      end

    filters =
      if limit = params["limit"] do
        limit_int = min(String.to_integer(limit), 100)
        Map.put(filters, :limit, limit_int)
      else
        Map.put(filters, :limit, 50)
      end

    filters =
      if offset = params["offset"] do
        Map.put(filters, :offset, String.to_integer(offset))
      else
        filters
      end

    filters
  end

  defp organization_to_json(%Organization{} = org) do
    %{
      id: OrganizationId.to_string(org.id),
      name: org.name,
      owner_email: Email.to_string(org.owner_email),
      status: org.status,
      verified: !is_nil(org.verified_at),
      verified_at: org.verified_at,
      plan_type: org.plan_type,
      max_users: org.max_users,
      max_api_calls_per_month: org.max_api_calls_per_month,
      api_calls_current_month: org.api_calls_current_month,
      members: Enum.map(org.members, &member_to_json/1),
      created_at: org.created_at,
      updated_at: org.updated_at
    }
  end

  defp member_to_json(%Organization.Member{} = member) do
    %{
      user_id: UserId.to_string(member.user_id),
      email: Email.to_string(member.email),
      role: member.role,
      joined_at: member.joined_at
    }
  end

  defp get_required_param(params, key) do
    case params[key] do
      nil -> {:error, :missing_parameter, key}
      "" -> {:error, :missing_parameter, key}
      value -> {:ok, value}
    end
  end

  defp apply_plan_type(organization, nil), do: organization

  defp apply_plan_type(organization, plan_type_string) do
    plan_type = String.to_existing_atom(plan_type_string)

    case Organization.upgrade_plan(organization, plan_type) do
      {:ok, updated_org} -> updated_org
      {:error, _} -> organization
    end
  end

  defp apply_updates(organization, params) do
    # Apply name update if present
    organization =
      if name = params["name"] do
        %{organization | name: name}
      else
        organization
      end

    # Apply status update if present
    organization =
      case params["status"] do
        "suspended" ->
          {:ok, updated} = Organization.suspend(organization)
          updated

        "active" ->
          {:ok, updated} = Organization.activate(organization)
          updated

        "inactive" ->
          {:ok, updated} = Organization.deactivate(organization)
          updated

        _ ->
          organization
      end

    # Apply plan type update if present
    organization =
      if plan_type_string = params["plan_type"] do
        plan_type = String.to_existing_atom(plan_type_string)

        case Organization.upgrade_plan(organization, plan_type) do
          {:ok, updated} -> updated
          {:error, _} -> organization
        end
      else
        organization
      end

    {:ok, organization}
  end

  @doc """
  POST /api/organizations/:id/members

  Add a member to an organization by email.

  ## Request Body (JSON)
  {
    "email": "user@example.com",
    "role": "admin|member|billing"
  }

  ## Response
  - 200 OK: Member added
  - 404 Not Found: Organization or user not found
  - 400 Bad Request: Invalid input or member already exists
  """
  def add_member(conn, %{"id" => id, "email" => email_string, "role" => role_string}) do
    with {:ok, org_id} <- OrganizationId.from_string(id),
         {:ok, organization} <- PostgreSQLOrganizationRepository.find_by_id(org_id),
         {:ok, email} <- Email.new(email_string),
         {:ok, user} <- PostgreSQLUserRepository.find_by_email(email),
         role <- String.to_existing_atom(role_string),
         {:ok, updated_org} <- Organization.add_member(organization, user.id, role),
         {:ok, _saved_org} <- PostgreSQLOrganizationRepository.save(updated_org) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: organization_to_json(updated_org),
        message: "Member added successfully"
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Organization or user not found"})

      {:error, :member_already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Member already exists in this organization"})

      {:error, :cannot_add_owner} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Cannot add a member with owner role"})

      {:error, :member_limit_reached} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Organization member limit reached"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to add member", details: inspect(reason)})
    end
  end

  def add_member(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters: email and role"})
  end

  @doc """
  DELETE /api/organizations/:id/members/:user_id

  Remove a member from an organization.

  ## Path Parameters
  - id: Organization UUID
  - user_id: User UUID to remove

  ## Response
  - 200 OK: Member removed
  - 404 Not Found: Organization or member not found
  - 400 Bad Request: Cannot remove owner
  """
  def remove_member(conn, %{"id" => id, "user_id" => user_id_string}) do
    with {:ok, org_id} <- OrganizationId.from_string(id),
         {:ok, user_id} <- UserId.from_string(user_id_string),
         {:ok, organization} <- PostgreSQLOrganizationRepository.find_by_id(org_id),
         {:ok, updated_org} <- Organization.remove_member(organization, user_id),
         {:ok, _saved_org} <- PostgreSQLOrganizationRepository.save(updated_org) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: organization_to_json(updated_org),
        message: "Member removed successfully"
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Organization not found"})

      {:error, :member_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Member not found in this organization"})

      {:error, :cannot_remove_owner} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Cannot remove the organization owner"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to remove member", details: inspect(reason)})
    end
  end

  def remove_member(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: user_id"})
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
