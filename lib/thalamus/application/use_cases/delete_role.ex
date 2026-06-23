defmodule Thalamus.Application.UseCases.DeleteRole do
  @moduledoc """
  Use case for deleting a role.

  SOLID Principles:
  - Single Responsibility: Only handles role deletion
  - Dependency Inversion: Depends on ports, not implementations
  """

  @type deps :: %{
          required(:role_repository) => module(),
          required(:cache_service) => module()
        }

  @type request :: %{
          role_id: binary()
        }

  @doc """
  Deletes a role and invalidates cache for affected users.

  ## Examples

      iex> DeleteRole.execute(%{role_id: "role_123"}, deps)
      {:ok, %{deleted_role_id: "role_123", invalidated_cache_for: 5}}
  """
  @spec execute(request(), deps()) :: {:ok, map()} | {:error, atom()}
  def execute(%{role_id: role_id}, deps) do
    with {:ok, user_ids} <- deps.role_repository.get_users_with_role(role_id),
         {:ok, _deleted_count} <- deps.role_repository.delete(role_id),
         invalidated_count <- invalidate_caches(user_ids, deps) do
      {:ok, %{deleted_role_id: role_id, invalidated_cache_for: invalidated_count}}
    end
  end

  defp invalidate_caches(user_ids, deps) do
    Enum.each(user_ids, fn user_id ->
      cache_key = "user_effective_scopes:#{user_id}"

      try do
        deps.cache_service.delete(cache_key)
      rescue
        _ -> :ok
      end
    end)

    length(user_ids)
  end
end
