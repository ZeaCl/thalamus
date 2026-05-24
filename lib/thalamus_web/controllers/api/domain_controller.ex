defmodule ThalamusWeb.API.DomainController do
  @moduledoc """
  Domain Management API Controller.

  Allows domains to register their permission models (scopes, roles)
  and enables organization admins to assign domain roles to users.
  Thalamus remains generic — it doesn't understand domain-specific semantics.
  """

  use ThalamusWeb, :controller

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{DomainScopeSchema, UserDomainRoleSchema, OrganizationSchema}

  import Ecto.Query

  @doc """
  POST /api/domains/register

  Register a domain's permission model (scopes).
  Called once per domain during setup.

  ## Request Body (JSON)
  {
    "domain": "venture",
    "scopes": [
      {"scope": "venture:fund.read", "description": "Ver fondos"},
      {"scope": "venture:fund.write", "description": "Crear/editar fondos"}
    ]
  }
  """
  def register(conn, %{"domain" => domain, "scopes" => scopes}) do
    # Upsert scopes — delete old ones for this domain, insert new ones
    Repo.delete_all(from ds in DomainScopeSchema, where: ds.domain == ^domain)

    entries =
      Enum.map(scopes, fn s ->
        %{
          id: Ecto.UUID.generate(),
          domain: domain,
          scope: s["scope"],
          description: s["description"],
          inserted_at: DateTime.truncate(DateTime.utc_now(), :second),
          updated_at: DateTime.truncate(DateTime.utc_now(), :second)
        }
      end)

    Repo.insert_all(DomainScopeSchema, entries)

    conn
    |> put_status(:ok)
    |> json(%{
      message: "Domain '#{domain}' registered with #{length(entries)} scopes",
      domain: domain,
      scope_count: length(entries)
    })
  end

  def register(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: domain, scopes"})
  end

  @doc """
  GET /api/domains

  List all registered domains and their scopes.
  """
  def index(conn, _params) do
    scopes = Repo.all(DomainScopeSchema)

    grouped =
      scopes
      |> Enum.group_by(& &1.domain)
      |> Enum.map(fn {domain, items} ->
        %{
          domain: domain,
          scopes: Enum.map(items, fn s -> %{scope: s.scope, description: s.description} end)
        }
      end)

    conn
    |> put_status(:ok)
    |> json(%{data: grouped})
  end

  @doc """
  POST /api/domains/roles/grant

  Grant a domain role to a user within an organization.
  The domain role includes a set of scopes.

  ## Request Body (JSON)
  {
    "user_id": "c0000000-...",
    "organization_id": "5fd11ea0-...",
    "domain": "venture",
    "role": "fund_manager",
    "scopes": ["venture:fund.*", "venture:capital_call.*"]
  }
  """
  def grant_role(conn, %{"user_id" => user_id, "organization_id" => org_id, "domain" => domain, "role" => role} = params) do
    scopes = Map.get(params, "scopes", [])

    # Check if already exists
    existing =
      Repo.one(
        from r in UserDomainRoleSchema,
          where:
            r.user_id == ^user_id and
              r.organization_id == ^org_id and
              r.domain == ^domain and
              r.role == ^role
      )

    if existing do
      # Update scopes
      Ecto.Changeset.cast(existing, %{scopes: scopes}, [:scopes])
      |> Repo.update!()

      conn
      |> put_status(:ok)
      |> json(%{message: "Role updated", user_id: user_id, domain: domain, role: role, scopes: scopes})
    else
      entry = %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        organization_id: org_id,
        domain: domain,
        role: role,
        scopes: scopes,
        inserted_at: DateTime.truncate(DateTime.utc_now(), :second),
        updated_at: DateTime.truncate(DateTime.utc_now(), :second)
      }

      Repo.insert_all(UserDomainRoleSchema, [entry])

      # Also add domain to organization's domains list
      org = Repo.get!(OrganizationSchema, org_id)
      current_domains = org.domains || []

      unless Enum.member?(current_domains, domain) do
        Ecto.Changeset.cast(org, %{domains: current_domains ++ [domain]}, [:domains])
        |> Repo.update!()
      end

      conn
      |> put_status(:created)
      |> json(%{message: "Role granted", user_id: user_id, domain: domain, role: role, scopes: scopes})
    end
  end

  def grant_role(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: user_id, organization_id, domain, role"})
  end

  @doc """
  DELETE /api/domains/roles/revoke

  Revoke a user's domain role.

  ## Request Body (JSON)
  {
    "user_id": "c0000000-...",
    "organization_id": "5fd11ea0-...",
    "domain": "venture",
    "role": "fund_manager"
  }
  """
  def revoke_role(conn, %{"user_id" => user_id, "organization_id" => org_id, "domain" => domain, "role" => role}) do
    Repo.delete_all(
      from r in UserDomainRoleSchema,
        where:
          r.user_id == ^user_id and
            r.organization_id == ^org_id and
            r.domain == ^domain and
            r.role == ^role
    )

    # Check if any roles remain for this domain in this org
    remaining =
      Repo.one(
        from r in UserDomainRoleSchema,
          where: r.organization_id == ^org_id and r.domain == ^domain,
          select: count(r.id)
      )

    if remaining == 0 do
      org = Repo.get!(OrganizationSchema, org_id)
      current = org.domains || []
      new_domains = List.delete(current, domain)
      Ecto.Changeset.cast(org, %{domains: new_domains}, [:domains])
      |> Repo.update!()
    end

    conn
    |> put_status(:ok)
    |> json(%{message: "Role revoked", user_id: user_id, domain: domain, role: role})
  end

  def revoke_role(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: user_id, organization_id, domain, role"})
  end

  @doc """
  GET /api/domains/roles

  List domain roles. Optional filters: user_id, organization_id, domain.

  ## Query Parameters
  - user_id: Filter by user
  - organization_id: Filter by organization
  - domain: Filter by domain
  """
  def list_roles(conn, params) do
    uid = params["user_id"]
    oid = params["organization_id"]
    domain_filter = params["domain"]

    dynamic_filters =
      Enum.reject([
        (if uid, do: dynamic([r], r.user_id == ^uid)),
        (if oid, do: dynamic([r], r.organization_id == ^oid)),
        (if domain_filter, do: dynamic([r], r.domain == ^domain_filter))
      ], &is_nil/1)

    query =
      Enum.reduce(dynamic_filters, from(r in UserDomainRoleSchema), fn filter, q ->
        where(q, ^filter)
      end)

    roles = Repo.all(query)

    result =
      Enum.map(roles, fn r ->
        %{
          id: r.id,
          user_id: r.user_id,
          organization_id: r.organization_id,
          domain: r.domain,
          role: r.role,
          scopes: r.scopes
        }
      end)

    conn
    |> put_status(:ok)
    |> json(%{data: result})
  end
end
