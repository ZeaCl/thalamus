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
