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
  @callback delete(binary()) ::
              {:ok, deleted_user_roles_count :: non_neg_integer()} | {:error, term()}

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
