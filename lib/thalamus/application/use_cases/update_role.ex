defmodule Thalamus.Application.UseCases.UpdateRole do
  @moduledoc """
  Use case for updating a role's scopes.

  SOLID Principles:
  - Single Responsibility: Only handles role updates
  - Dependency Inversion: Depends on ports, not implementations
  """

  alias Thalamus.Domain.Entities.Role

  @type deps :: %{
          required(:role_repository) => module(),
          required(:cache_service) => module()
        }

  @type request :: %{
          role_id: binary(),
          scopes: [String.t()]
        }

  @doc """
  Updates a role's scopes and invalidates cache for affected users.

  ## Examples

      iex> request = %{role_id: "role_123", scopes: ["read:code", "write:code"]}
      iex> UpdateRole.execute(request, deps)
      {:ok, %{role: %Role{}, invalidated_cache_for: 5}}
  """
  @spec execute(request(), deps()) :: {:ok, map()} | {:error, atom()}
  def execute(%{role_id: role_id, scopes: new_scopes}, deps) do
    with {:ok, role} <- deps.role_repository.find_by_id(role_id),
         {:ok, updated_role} <- Role.update_scopes(role, new_scopes),
         {:ok, saved_role} <- deps.role_repository.save(updated_role),
         {:ok, user_ids} <- deps.role_repository.get_users_with_role(role_id),
         invalidated_count <- invalidate_caches(user_ids, deps) do
      {:ok, %{role: saved_role, invalidated_cache_for: invalidated_count}}
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
