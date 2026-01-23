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

  @cache_ttl 300_000  # 5 minutes in milliseconds

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

      {:error, _reason} ->
        # Treat any cache error as cache miss
        calculate_and_cache(user_id, cache_key, deps)
    end
  end

  defp calculate_and_cache(user_id, cache_key, deps) do
    {:ok, roles} = deps.role_repository.get_user_roles(user_id)

    effective_scopes = calculate_effective_scopes(roles)

    # Cache with TTL (fire and forget - don't fail if cache unavailable)
    try do
      deps.cache_service.set(cache_key, effective_scopes, @cache_ttl)
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
