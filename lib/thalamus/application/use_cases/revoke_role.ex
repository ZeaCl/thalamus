defmodule Thalamus.Application.UseCases.RevokeRole do
  @moduledoc """
  Use case for revoking a role from a user.

  SOLID Principles:
  - Single Responsibility: Only handles role revocation workflow
  - Dependency Inversion: Depends on ports, not implementations
  """

  require Logger

  @type deps :: %{
          required(:role_repository) => module(),
          required(:cache_service) => module(),
          required(:audit_logger) => module()
        }

  @type request :: %{
          user_id: binary(),
          role_id: binary(),
          revoked_by: binary() | nil
        }

  @doc """
  Executes role revocation.

  ## Flow
  1. Revoke role via repository
  2. Invalidate user's effective scopes cache
  3. Log audit event

  ## Examples

      iex> request = %{user_id: "user_123", role_id: "role_456", revoked_by: "admin_789"}
      iex> RevokeRole.execute(request, deps)
      {:ok, %{user_id: "user_123", role_id: "role_456", revoked_at: ~U[...]}}
  """
  @spec execute(request(), deps()) :: {:ok, map()} | {:error, atom()}
  def execute(%{user_id: user_id, role_id: role_id} = request, deps) do
    with :ok <- revoke_role(user_id, role_id, deps),
         :ok <- invalidate_cache(user_id, deps),
         :ok <- log_revocation(user_id, role_id, request[:revoked_by], deps) do
      {:ok,
       %{
         user_id: user_id,
         role_id: role_id,
         revoked_at: DateTime.truncate(DateTime.utc_now(), :second)
       }}
    end
  end

  defp revoke_role(user_id, role_id, deps) do
    case deps.role_repository.revoke_from_user(user_id, role_id) do
      :ok -> :ok
      {:error, :not_found} -> {:error, :assignment_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp invalidate_cache(user_id, deps) do
    cache_key = "user_effective_scopes:#{user_id}"
    deps.cache_service.delete(cache_key)
    :ok
  rescue
    _ -> :ok  # Cache failure should not block revocation
  end

  defp log_revocation(user_id, role_id, revoked_by, deps) do
    deps.audit_logger.log(%{
      event_type: "role.revoked",
      actor_type: "user",
      actor_id: revoked_by,
      resource_type: "user_role",
      resource_id: "#{user_id}:#{role_id}",
      metadata: %{
        user_id: user_id,
        role_id: role_id,
        revoked_by: revoked_by
      }
    })

    :ok
  end
end
