# Components & Code
## Epic 9: Role-Based Access Control (RBAC)

**Document Version:** 1.0
**Date:** January 17, 2026
**Status:** Design Phase (Phase 2)

---

## 📦 Component Overview

This document contains **copy-paste ready** code for all components in Epic 9 RBAC, organized by Clean Architecture layer.

---

## 🎯 Domain Layer

### 1. Permission Value Object

**File:** `lib/thalamus/domain/value_objects/permission.ex`

```elixir
defmodule Thalamus.Domain.ValueObjects.Permission do
  @moduledoc """
  Value Object representing a permission scope.

  Supports multiple scope formats for agentic workflows:
  - OIDC standard: `openid`, `profile`, `email`
  - Namespaced: `zea:read`, `cortex:chat`
  - MCP servers: `mcp:gmail:read`, `mcp:slack:write`
  - Multi-level: `mcp:slack:channels:list` (max 4 levels)

  SOLID Principles:
  - Single Responsibility: Only validates scope format
  - Open/Closed: Extensible via regex pattern updates
  """

  @type t :: %__MODULE__{value: String.t()}
  defstruct [:value]

  # Matches: single word OR colon-separated (max 4 levels)
  # Examples:
  #   openid               ✓
  #   zea:read             ✓
  #   mcp:gmail:read       ✓
  #   mcp:slack:channels:list  ✓
  @scope_regex ~r/^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){0,3}$/

  @max_length 128

  @doc """
  Creates a new Permission value object from a scope string.

  ## Examples

      iex> Permission.new("openid")
      {:ok, %Permission{value: "openid"}}

      iex> Permission.new("zea:read")
      {:ok, %Permission{value: "zea:read"}}

      iex> Permission.new("mcp:gmail:read")
      {:ok, %Permission{value: "mcp:gmail:read"}}

      iex> Permission.new("mcp:slack:channels:list")
      {:ok, %Permission{value: "mcp:slack:channels:list"}}

      iex> Permission.new("invalid scope!")
      {:error, :invalid_scope_format}

      iex> Permission.new(String.duplicate("a", 130))
      {:error, :scope_too_long}
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, atom()}
  def new(scope) when is_binary(scope) do
    cond do
      String.length(scope) > @max_length ->
        {:error, :scope_too_long}

      not valid_format?(scope) ->
        {:error, :invalid_scope_format}

      true ->
        {:ok, %__MODULE__{value: scope}}
    end
  end

  def new(_), do: {:error, :invalid_scope_format}

  @doc """
  Validates a scope string format without creating the value object.

  ## Examples

      iex> Permission.valid_format?("openid")
      true

      iex> Permission.valid_format?("mcp:gmail:read")
      true

      iex> Permission.valid_format?("invalid!")
      false
  """
  @spec valid_format?(String.t()) :: boolean()
  def valid_format?(scope) when is_binary(scope) do
    Regex.match?(@scope_regex, scope)
  end

  def valid_format?(_), do: false

  @doc """
  Converts the Permission to its string representation.

  ## Examples

      iex> {:ok, perm} = Permission.new("zea:read")
      iex> Permission.to_string(perm)
      "zea:read"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value
end

# Protocol implementations
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.Permission do
  def to_string(%{value: value}), do: value
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.Permission do
  def encode(%{value: value}, opts), do: Jason.Encode.string(value, opts)
end
```

---

### 2. Role Entity

**File:** `lib/thalamus/domain/entities/role.ex`

```elixir
defmodule Thalamus.Domain.Entities.Role do
  @moduledoc """
  Role Entity - Aggregate for managing user permissions via roles.

  A Role is a named collection of scopes that can be assigned to multiple users
  within an organization. Users inherit all scopes from their assigned roles.

  SOLID Principles:
  - Single Responsibility: Manages role state and validation
  - Open/Closed: Extensible via new validation rules
  - Dependency Inversion: Uses Permission value object for scope validation
  """

  alias Thalamus.Domain.ValueObjects.Permission

  @type t :: %__MODULE__{
          id: binary() | nil,
          organization_id: binary(),
          name: String.t(),
          description: String.t() | nil,
          scopes: [String.t()],
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :organization_id,
    :name,
    :description,
    :scopes,
    :created_at,
    :updated_at
  ]

  @max_name_length 100
  @max_description_length 500

  @doc """
  Creates a new Role entity.

  ## Examples

      iex> Role.new(%{
      ...>   organization_id: "org_abc123",
      ...>   name: "Developer",
      ...>   description: "Read and write code",
      ...>   scopes: ["read:code", "write:code"]
      ...> })
      {:ok, %Role{name: "Developer", scopes: ["read:code", "write:code"]}}

      iex> Role.new(%{organization_id: "org_abc", name: "", scopes: []})
      {:error, :invalid_name}
  """
  @spec new(map()) :: {:ok, t()} | {:error, atom()}
  def new(attrs) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    role = %__MODULE__{
      id: Map.get(attrs, :id),
      organization_id: attrs[:organization_id],
      name: Map.get(attrs, :name, "") |> String.trim(),
      description: Map.get(attrs, :description),
      scopes: Map.get(attrs, :scopes, []),
      created_at: Map.get(attrs, :created_at, now),
      updated_at: Map.get(attrs, :updated_at, now)
    }

    case validate(role) do
      :ok -> {:ok, role}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates role scopes.

  Returns a new Role entity with updated scopes and timestamp.

  ## Examples

      iex> {:ok, role} = Role.new(%{organization_id: "org_abc", name: "Dev", scopes: ["read:code"]})
      iex> Role.update_scopes(role, ["read:code", "write:code"])
      {:ok, %Role{scopes: ["read:code", "write:code"]}}
  """
  @spec update_scopes(t(), [String.t()]) :: {:ok, t()} | {:error, atom()}
  def update_scopes(%__MODULE__{} = role, new_scopes) when is_list(new_scopes) do
    updated_role = %{
      role
      | scopes: new_scopes,
        updated_at: DateTime.truncate(DateTime.utc_now(), :second)
    }

    case validate_scopes(new_scopes) do
      :ok -> {:ok, updated_role}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_scopes(_, _), do: {:error, :invalid_scopes}

  @doc """
  Adds a scope to the role.

  ## Examples

      iex> {:ok, role} = Role.new(%{organization_id: "org_abc", name: "Dev", scopes: ["read:code"]})
      iex> Role.add_scope(role, "write:code")
      {:ok, %Role{scopes: ["read:code", "write:code"]}}
  """
  @spec add_scope(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def add_scope(%__MODULE__{scopes: scopes} = role, new_scope) do
    case Permission.new(new_scope) do
      {:ok, _permission} ->
        if new_scope in scopes do
          {:ok, role}
        else
          update_scopes(role, scopes ++ [new_scope])
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Removes a scope from the role.

  ## Examples

      iex> {:ok, role} = Role.new(%{organization_id: "org_abc", name: "Dev", scopes: ["read:code", "write:code"]})
      iex> Role.remove_scope(role, "write:code")
      {:ok, %Role{scopes: ["read:code"]}}
  """
  @spec remove_scope(t(), String.t()) :: {:ok, t()}
  def remove_scope(%__MODULE__{scopes: scopes} = role, scope_to_remove) do
    new_scopes = Enum.reject(scopes, fn s -> s == scope_to_remove end)
    updated_role = %{
      role
      | scopes: new_scopes,
        updated_at: DateTime.truncate(DateTime.utc_now(), :second)
    }

    {:ok, updated_role}
  end

  # Private functions

  defp validate(%__MODULE__{} = role) do
    with :ok <- validate_organization_id(role.organization_id),
         :ok <- validate_name(role.name),
         :ok <- validate_description(role.description),
         :ok <- validate_scopes(role.scopes) do
      :ok
    end
  end

  defp validate_organization_id(nil), do: {:error, :missing_organization_id}
  defp validate_organization_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp validate_organization_id(_), do: {:error, :invalid_organization_id}

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0 do
    if String.length(name) <= @max_name_length do
      :ok
    else
      {:error, :name_too_long}
    end
  end

  defp validate_name(_), do: {:error, :invalid_name}

  defp validate_description(nil), do: :ok

  defp validate_description(desc) when is_binary(desc) do
    if String.length(desc) <= @max_description_length do
      :ok
    else
      {:error, :description_too_long}
    end
  end

  defp validate_description(_), do: {:error, :invalid_description}

  defp validate_scopes(scopes) when is_list(scopes) do
    Enum.reduce_while(scopes, :ok, fn scope, _acc ->
      case Permission.new(scope) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_scopes(_), do: {:error, :invalid_scopes}
end

# Protocol implementations
defimpl String.Chars, for: Thalamus.Domain.Entities.Role do
  def to_string(%{name: name}), do: "Role<#{name}>"
end

defimpl Jason.Encoder, for: Thalamus.Domain.Entities.Role do
  def encode(%Thalamus.Domain.Entities.Role{} = role, opts) do
    %{
      id: role.id,
      organization_id: role.organization_id,
      name: role.name,
      description: role.description,
      scopes: role.scopes,
      created_at: role.created_at,
      updated_at: role.updated_at
    }
    |> Jason.Encode.map(opts)
  end
end
```

---

## 🔌 Application Layer

### 3. RoleRepository Port

**File:** `lib/thalamus/application/ports/role_repository.ex`

```elixir
defmodule Thalamus.Application.Ports.RoleRepository do
  @moduledoc """
  Port (behaviour) for Role repository operations.

  Defines the interface that infrastructure layer must implement.

  SOLID Principles:
  - Interface Segregation: Focused on role-specific operations
  - Dependency Inversion: Application depends on this interface, not implementations
  """

  alias Thalamus.Domain.Entities.Role

  @doc """
  Saves a role (insert or update).
  """
  @callback save(Role.t()) :: {:ok, Role.t()} | {:error, term()}

  @doc """
  Finds a role by ID.
  """
  @callback find_by_id(binary()) :: {:ok, Role.t()} | {:error, :not_found}

  @doc """
  Finds a role by name within an organization.
  """
  @callback find_by_name(organization_id :: binary(), name :: String.t()) ::
              {:ok, Role.t()} | {:error, :not_found}

  @doc """
  Lists all roles for an organization.
  """
  @callback list_by_organization(organization_id :: binary()) :: {:ok, [Role.t()]}

  @doc """
  Deletes a role by ID.
  Returns the number of user_role assignments that were deleted.
  """
  @callback delete(binary()) :: {:ok, deleted_user_roles_count :: non_neg_integer()} | {:error, term()}

  @doc """
  Assigns a role to a user.
  """
  @callback assign_to_user(
              user_id :: binary(),
              role_id :: binary(),
              assigned_by :: binary() | nil
            ) :: {:ok, user_role :: map()} | {:error, term()}

  @doc """
  Revokes a role from a user.
  """
  @callback revoke_from_user(user_id :: binary(), role_id :: binary()) :: :ok | {:error, term()}

  @doc """
  Gets all roles assigned to a user.
  """
  @callback get_user_roles(user_id :: binary()) :: {:ok, [Role.t()]}

  @doc """
  Gets all user IDs that have a specific role.
  """
  @callback get_users_with_role(role_id :: binary()) :: {:ok, [binary()]}
end
```

---

### 4. AssignRole Use Case

**File:** `lib/thalamus/application/use_cases/assign_role.ex`

```elixir
defmodule Thalamus.Application.UseCases.AssignRole do
  @moduledoc """
  Use case for assigning a role to a user.

  SOLID Principles:
  - Single Responsibility: Only handles role assignment workflow
  - Dependency Inversion: Depends on ports, not implementations
  - Open/Closed: Extensible via additional validations without modification
  """

  require Logger

  @type deps :: %{
          required(:role_repository) => module(),
          required(:user_repository) => module(),
          required(:cache_service) => module(),
          required(:audit_logger) => module()
        }

  @type request :: %{
          user_id: binary(),
          role_id: binary(),
          assigned_by: binary() | nil
        }

  @doc """
  Executes role assignment.

  ## Flow
  1. Validate user exists and is active
  2. Validate role exists
  3. Validate user and role in same organization
  4. Assign role via repository (idempotent)
  5. Invalidate user's effective scopes cache
  6. Log audit event

  ## Examples

      iex> request = %{user_id: "user_123", role_id: "role_456", assigned_by: "admin_789"}
      iex> AssignRole.execute(request, deps)
      {:ok, %{user_id: "user_123", role_id: "role_456", assigned_at: ~U[...]}}
  """
  @spec execute(request(), deps()) :: {:ok, map()} | {:error, atom()}
  def execute(%{user_id: user_id, role_id: role_id} = request, deps) do
    with {:ok, user} <- deps.user_repository.find_by_id(user_id),
         :ok <- validate_user_active(user),
         {:ok, role} <- deps.role_repository.find_by_id(role_id),
         :ok <- validate_same_organization(user, role),
         {:ok, user_role} <- assign_role(user_id, role_id, request[:assigned_by], deps),
         :ok <- invalidate_cache(user_id, deps),
         :ok <- log_assignment(user_id, role_id, request[:assigned_by], deps) do
      {:ok, user_role}
    end
  end

  defp validate_user_active(%{status: :active}), do: :ok
  defp validate_user_active(_), do: {:error, :user_not_active}

  defp validate_same_organization(user, role) do
    if user.organization_id == role.organization_id do
      :ok
    else
      {:error, :organization_mismatch}
    end
  end

  defp assign_role(user_id, role_id, assigned_by, deps) do
    deps.role_repository.assign_to_user(user_id, role_id, assigned_by)
  end

  defp invalidate_cache(user_id, deps) do
    cache_key = "user_effective_scopes:#{user_id}"
    deps.cache_service.delete(cache_key)
    :ok
  rescue
    _ -> :ok  # Cache failure should not block assignment
  end

  defp log_assignment(user_id, role_id, assigned_by, deps) do
    deps.audit_logger.log(%{
      event_type: "role.assigned",
      actor_type: "user",
      actor_id: assigned_by,
      resource_type: "user_role",
      resource_id: "#{user_id}:#{role_id}",
      metadata: %{
        user_id: user_id,
        role_id: role_id,
        assigned_by: assigned_by
      }
    })

    :ok
  end
end
```

---

### 5. GetEffectiveScopes Use Case

**File:** `lib/thalamus/application/use_cases/get_effective_scopes.ex`

```elixir
defmodule Thalamus.Application.UseCases.GetEffectiveScopes do
  @moduledoc """
  Use case for calculating user's effective scopes from all assigned roles.

  Effective scopes = union of all scopes from all assigned roles.

  SOLID Principles:
  - Single Responsibility: Only calculates effective scopes
  - Dependency Inversion: Depends on ports for roles and cache
  """

  @type deps :: %{
          required(:role_repository) => module(),
          required(:cache_service) => module()
        }

  @cache_ttl 300  # 5 minutes

  @doc """
  Gets effective scopes for a user.

  Checks cache first. On cache miss, queries all user roles,
  calculates union of scopes, stores in cache, and returns.

  ## Examples

      iex> GetEffectiveScopes.execute("user_123", deps)
      {:ok, ["read:data", "write:data", "admin"]}

      iex> GetEffectiveScopes.execute("user_with_no_roles", deps)
      {:ok, []}
  """
  @spec execute(binary(), deps()) :: {:ok, [String.t()]}
  def execute(user_id, deps) when is_binary(user_id) do
    cache_key = "user_effective_scopes:#{user_id}"

    case deps.cache_service.get(cache_key) do
      {:ok, cached_scopes} ->
        {:ok, cached_scopes}

      {:error, :not_found} ->
        calculate_and_cache(user_id, cache_key, deps)
    end
  end

  defp calculate_and_cache(user_id, cache_key, deps) do
    {:ok, roles} = deps.role_repository.get_user_roles(user_id)

    effective_scopes = calculate_effective_scopes(roles)

    # Cache with TTL (fire and forget - don't fail if cache unavailable)
    try do
      deps.cache_service.put(cache_key, effective_scopes, @cache_ttl)
    rescue
      _ -> :ok
    end

    {:ok, effective_scopes}
  end

  defp calculate_effective_scopes(roles) do
    roles
    |> Enum.flat_map(fn role -> role.scopes end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
```

---

### 6. Updated GenerateAgentToken Use Case

**File:** `lib/thalamus/application/use_cases/generate_agent_token.ex` (UPDATED)

```elixir
# This is the UPDATED version of the existing validate_delegator_has_scopes function
# Location: Around line 146-166

defp validate_delegator_has_scopes(user, requested_scopes, deps) do
  # Get user's effective scopes (from roles)
  case deps.user_repository.get_effective_scopes(user.id) do
    {:ok, []} ->
      # User has no roles assigned - allow delegation (backward compatibility)
      # This ensures existing users without roles continue to work
      Logger.info("User #{user.id} has no roles, allowing delegation (backward compatible)")
      :ok

    {:ok, user_scopes} ->
      # User has roles - enforce scope validation
      requested_set = MapSet.new(requested_scopes)
      user_set = MapSet.new(user_scopes)

      if MapSet.subset?(requested_set, user_set) do
        :ok
      else
        Logger.warning(
          "User #{user.id} attempted to delegate scopes beyond their permissions. " <>
            "Requested: #{inspect(requested_scopes)}, User scopes: #{inspect(user_scopes)}"
        )

        {:error, :delegator_insufficient_permissions}
      end

    {:error, reason} ->
      {:error, reason}
  end
end
```

---

## 🏗️ Infrastructure Layer

### 7. RoleSchema

**File:** `lib/thalamus/infrastructure/persistence/schemas/role_schema.ex`

```elixir
defmodule Thalamus.Infrastructure.Persistence.Schemas.RoleSchema do
  @moduledoc """
  Ecto schema for Role persistence.

  Maps the Role domain entity to the database.

  SOLID Principles:
  - Single Responsibility: Only handles database mapping
  - Dependency Inversion: Domain entities don't depend on this schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{OrganizationSchema, UserRoleSchema}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "roles" do
    field :name, :string
    field :description, :string
    field :scopes, {:array, :string}, default: []

    belongs_to :organization, OrganizationSchema
    has_many :user_roles, UserRoleSchema, foreign_key: :role_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a role.
  """
  def changeset(role \\ %__MODULE__{}, attrs) do
    role
    |> cast(attrs, [:name, :description, :scopes, :organization_id])
    |> validate_required([:name, :organization_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_scopes()
    |> unique_constraint([:organization_id, :name],
      name: :roles_organization_id_name_index,
      message: "role name must be unique within organization"
    )
  end

  defp validate_scopes(changeset) do
    case get_change(changeset, :scopes) do
      nil ->
        changeset

      scopes when is_list(scopes) ->
        if Enum.all?(scopes, &valid_scope_format?/1) do
          changeset
        else
          add_error(changeset, :scopes, "contains invalid scope format")
        end

      _ ->
        add_error(changeset, :scopes, "must be a list of strings")
    end
  end

  # Validates scope format: ^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){0,3}$
  defp valid_scope_format?(scope) when is_binary(scope) do
    String.match?(scope, ~r/^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){0,3}$/) and
      String.length(scope) <= 128
  end

  defp valid_scope_format?(_), do: false
end
```

---

### 8. UserRoleSchema

**File:** `lib/thalamus/infrastructure/persistence/schemas/user_role_schema.ex`

```elixir
defmodule Thalamus.Infrastructure.Persistence.Schemas.UserRoleSchema do
  @moduledoc """
  Ecto schema for UserRole join table.

  Represents the many-to-many relationship between users and roles.

  SOLID Principles:
  - Single Responsibility: Only handles user-role association mapping
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, RoleSchema}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_roles" do
    belongs_to :user, UserSchema
    belongs_to :role, RoleSchema
    field :assigned_by, :binary_id
    field :assigned_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating a user-role assignment.
  """
  def changeset(user_role \\ %__MODULE__{}, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :assigned_by, :assigned_at])
    |> validate_required([:user_id, :role_id])
    |> put_timestamp_if_missing()
    |> unique_constraint([:user_id, :role_id],
      name: :user_roles_user_id_role_id_index,
      message: "user already has this role assigned"
    )
  end

  defp put_timestamp_if_missing(changeset) do
    case get_field(changeset, :assigned_at) do
      nil -> put_change(changeset, :assigned_at, DateTime.truncate(DateTime.utc_now(), :second))
      _ -> changeset
    end
  end
end
```

---

### 9. PostgresqlRoleRepository

**File:** `lib/thalamus/infrastructure/repositories/postgresql_role_repository.ex`

```elixir
defmodule Thalamus.Infrastructure.Repositories.PostgresqlRoleRepository do
  @moduledoc """
  PostgreSQL implementation of RoleRepository port.

  SOLID Principles:
  - Single Responsibility: Only handles role persistence
  - Dependency Inversion: Implements port defined in application layer
  """

  @behaviour Thalamus.Application.Ports.RoleRepository

  import Ecto.Query
  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.Role
  alias Thalamus.Infrastructure.Persistence.Schemas.{RoleSchema, UserRoleSchema}

  @impl true
  def save(%Role{id: nil} = role) do
    %RoleSchema{}
    |> RoleSchema.changeset(to_map(role))
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def save(%Role{id: id} = role) do
    case Repo.get(RoleSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> RoleSchema.changeset(to_map(role))
        |> Repo.update()
        |> case do
          {:ok, updated_schema} -> {:ok, to_domain(updated_schema)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def find_by_id(id) do
    case Repo.get(RoleSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def find_by_name(organization_id, name) do
    query =
      from r in RoleSchema,
        where: r.organization_id == ^organization_id,
        where: r.name == ^name

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def list_by_organization(organization_id) do
    query =
      from r in RoleSchema,
        where: r.organization_id == ^organization_id,
        order_by: [asc: r.name]

    roles =
      query
      |> Repo.all()
      |> Enum.map(&to_domain/1)

    {:ok, roles}
  end

  @impl true
  def delete(id) do
    case Repo.get(RoleSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        # Count affected user_roles before deletion (CASCADE will delete them)
        user_roles_count =
          from(ur in UserRoleSchema, where: ur.role_id == ^id, select: count(ur.id))
          |> Repo.one()

        case Repo.delete(schema) do
          {:ok, _} -> {:ok, user_roles_count}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def assign_to_user(user_id, role_id, assigned_by) do
    attrs = %{
      user_id: user_id,
      role_id: role_id,
      assigned_by: assigned_by
    }

    %UserRoleSchema{}
    |> UserRoleSchema.changeset(attrs)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:user_id, :role_id]
    )
    |> case do
      {:ok, user_role} ->
        {:ok,
         %{
           user_id: user_role.user_id,
           role_id: user_role.role_id,
           assigned_at: user_role.assigned_at
         }}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  def revoke_from_user(user_id, role_id) do
    query =
      from ur in UserRoleSchema,
        where: ur.user_id == ^user_id,
        where: ur.role_id == ^role_id

    case Repo.delete_all(query) do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
      {_, _} -> :ok  # Multiple deleted (shouldn't happen due to unique constraint)
    end
  end

  @impl true
  def get_user_roles(user_id) do
    query =
      from r in RoleSchema,
        join: ur in UserRoleSchema,
        on: ur.role_id == r.id,
        where: ur.user_id == ^user_id,
        order_by: [asc: r.name]

    roles =
      query
      |> Repo.all()
      |> Enum.map(&to_domain/1)

    {:ok, roles}
  end

  @impl true
  def get_users_with_role(role_id) do
    query =
      from ur in UserRoleSchema,
        where: ur.role_id == ^role_id,
        select: ur.user_id

    user_ids = Repo.all(query)
    {:ok, user_ids}
  end

  # Private functions

  defp to_domain(%RoleSchema{} = schema) do
    %Role{
      id: schema.id,
      organization_id: schema.organization_id,
      name: schema.name,
      description: schema.description,
      scopes: schema.scopes || [],
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp to_map(%Role{} = role) do
    %{
      id: role.id,
      organization_id: role.organization_id,
      name: role.name,
      description: role.description,
      scopes: role.scopes
    }
  end
end
```

---

## 🌐 Presentation Layer

### 10. RoleController

**File:** `lib/thalamus_web/controllers/api/role_controller.ex`

```elixir
defmodule ThalamusWeb.API.RoleController do
  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.{AssignRole, RevokeRole}
  alias Thalamus.Application.Ports.RoleRepository
  alias Thalamus.Domain.Entities.Role

  # Dependency injection via Application config
  @role_repo Application.compile_env(:thalamus, :role_repository)
  @user_repo Application.compile_env(:thalamus, :user_repository)
  @cache_service Application.compile_env(:thalamus, :cache_service)
  @audit_logger Application.compile_env(:thalamus, :audit_logger)

  @doc """
  Lists all roles for the authenticated user's organization.

  GET /api/roles
  """
  def index(conn, _params) do
    organization_id = conn.assigns.current_user.organization_id

    case @role_repo.list_by_organization(organization_id) do
      {:ok, roles} ->
        json(conn, %{roles: roles})
    end
  end

  @doc """
  Creates a new role in the organization.

  POST /api/roles
  Body: {name, description, scopes}
  """
  def create(conn, %{"name" => name} = params) do
    organization_id = conn.assigns.current_user.organization_id

    attrs = %{
      organization_id: organization_id,
      name: name,
      description: params["description"],
      scopes: params["scopes"] || []
    }

    case Role.new(attrs) do
      {:ok, role} ->
        case @role_repo.save(role) do
          {:ok, saved_role} ->
            conn
            |> put_status(:created)
            |> json(saved_role)

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: translate_errors(changeset)})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: reason})
        end

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  @doc """
  Shows a single role.

  GET /api/roles/:id
  """
  def show(conn, %{"id" => id}) do
    organization_id = conn.assigns.current_user.organization_id

    case @role_repo.find_by_id(id) do
      {:ok, role} ->
        if role.organization_id == organization_id do
          json(conn, role)
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden"})
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "role not found"})
    end
  end

  @doc """
  Updates a role's scopes or description.

  PATCH /api/roles/:id
  Body: {scopes?, description?}
  """
  def update(conn, %{"id" => id} = params) do
    organization_id = conn.assigns.current_user.organization_id

    with {:ok, role} <- @role_repo.find_by_id(id),
         :ok <- validate_organization(role, organization_id),
         {:ok, updated_role} <- update_role_fields(role, params),
         {:ok, saved_role} <- @role_repo.save(updated_role),
         :ok <- invalidate_affected_users(id) do
      json(conn, saved_role)
    else
      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "role not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  @doc """
  Deletes a role.

  DELETE /api/roles/:id?confirm=true
  """
  def delete(conn, %{"id" => id} = params) do
    organization_id = conn.assigns.current_user.organization_id

    with {:ok, role} <- @role_repo.find_by_id(id),
         :ok <- validate_organization(role, organization_id),
         :ok <- check_confirmation_if_needed(id, params),
         {:ok, affected_count} <- @role_repo.delete(id),
         :ok <- invalidate_affected_users(id) do
      json(conn, %{deleted: true, affected_users: affected_count})
    else
      {:error, :confirmation_required} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "confirmation required (role has >10 users)"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "role not found"})
    end
  end

  # Private functions

  defp validate_organization(role, organization_id) do
    if role.organization_id == organization_id do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp update_role_fields(role, params) do
    role =
      if params["description"], do: %{role | description: params["description"]}, else: role

    if params["scopes"] do
      Role.update_scopes(role, params["scopes"])
    else
      {:ok, role}
    end
  end

  defp check_confirmation_if_needed(role_id, params) do
    {:ok, user_ids} = @role_repo.get_users_with_role(role_id)

    if length(user_ids) > 10 and params["confirm"] != "true" do
      {:error, :confirmation_required}
    else
      :ok
    end
  end

  defp invalidate_affected_users(role_id) do
    {:ok, user_ids} = @role_repo.get_users_with_role(role_id)

    Enum.each(user_ids, fn user_id ->
      cache_key = "user_effective_scopes:#{user_id}"
      @cache_service.delete(cache_key)
    end)

    :ok
  rescue
    _ -> :ok  # Cache failure should not block operation
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

---

## 📝 Summary

This document provides **production-ready code** for:

✅ **Domain Layer:** Role entity, Permission value object
✅ **Application Layer:** RoleRepository port, 3 use cases
✅ **Infrastructure Layer:** Ecto schemas, PostgreSQL repository
✅ **Presentation Layer:** RoleController with full CRUD

**All code follows:**
- Clean Architecture principles
- SOLID principles
- Existing Thalamus patterns
- Comprehensive error handling
- Multi-tenant isolation
- Backward compatibility

**Next:** [02-design-database.md](02-design-database.md) - Database migrations and schema
