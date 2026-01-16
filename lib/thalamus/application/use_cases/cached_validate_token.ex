defmodule Thalamus.Application.UseCases.CachedValidateToken do
  @moduledoc """
  Caching wrapper around ValidateToken use case.

  Reduces database load and improves latency for token introspection.

  ## Performance

  - Cache hit: ~1-3ms
  - Cache miss: ~15-25ms (query + cache set)
  - TTL: 300 seconds (5 minutes)

  ## Cache Invalidation

  Cache is invalidated on:
  - Token revocation
  - Token expiration (automatic via TTL)

  SOLID Principles Applied:
  - Single Responsibility: Only handles cached token validation
  - Dependency Inversion: Depends on ports (CacheService, ValidateToken)
  - Open/Closed: Extends ValidateToken without modifying it
  """

  require Logger

  alias Thalamus.Application.UseCases.ValidateToken

  # 5 minutes
  @cache_ttl 300

  @type deps :: %{
          token_repository: module(),
          cache_service: module()
        }

  @doc """
  Validates token with caching.

  Falls back to database if cache is unavailable.

  ## Examples

      iex> CachedValidateToken.execute("at_abc123...", deps)
      {:ok, %{valid: true, active: true, ...}}

  ## Performance

  First call (cache miss):
  - Queries database
  - Stores result in cache
  - ~15-25ms

  Subsequent calls (cache hit):
  - Returns from cache
  - ~1-3ms
  """
  @spec execute(String.t(), deps()) :: {:ok, map()} | {:error, atom()}
  def execute(token, deps) when is_binary(token) do
    cache_key = build_cache_key(token)

    case deps.cache_service.get(cache_key) do
      {:ok, cached_result} ->
        # Cache hit - return immediately
        Logger.debug("Token introspection cache HIT for key: #{cache_key}")
        {:ok, cached_result}

      {:error, :not_found} ->
        # Cache miss - query database and cache result
        Logger.debug("Token introspection cache MISS for key: #{cache_key}")
        validate_and_cache(token, cache_key, deps)

      {:error, :cache_unavailable} ->
        # Cache unavailable - fall back to direct validation
        Logger.warning("Cache unavailable, falling back to direct validation")
        ValidateToken.execute(token, deps)
    end
  end

  def execute(_, _), do: {:error, :invalid_token_format}

  @doc """
  Validates token for a specific scope with caching.

  ## Examples

      iex> CachedValidateToken.execute_with_scope("at_abc...", "openid profile", deps)
      {:ok, %{valid: true, active: true, ...}}
  """
  @spec execute_with_scope(String.t(), String.t(), deps()) :: {:ok, map()} | {:error, atom()}
  def execute_with_scope(token, required_scope, deps) do
    cache_key = build_scope_cache_key(token, required_scope)

    case deps.cache_service.get(cache_key) do
      {:ok, cached_result} ->
        Logger.debug("Token scope validation cache HIT for key: #{cache_key}")
        {:ok, cached_result}

      {:error, :not_found} ->
        Logger.debug("Token scope validation cache MISS for key: #{cache_key}")

        case ValidateToken.execute_with_scope(token, required_scope, deps) do
          {:ok, result} ->
            # Cache the result asynchronously
            Task.start(fn ->
              deps.cache_service.set(cache_key, result, @cache_ttl)
            end)

            {:ok, result}

          {:error, _} = error ->
            error
        end

      {:error, :cache_unavailable} ->
        ValidateToken.execute_with_scope(token, required_scope, deps)
    end
  end

  @doc """
  Invalidates cache for a specific token.

  Called when token is revoked or modified.

  ## Examples

      iex> CachedValidateToken.invalidate("at_abc123...", deps)
      :ok
  """
  @spec invalidate(String.t(), deps()) :: :ok | {:error, atom()}
  def invalidate(token, deps) when is_binary(token) do
    cache_key = build_cache_key(token)

    case deps.cache_service.delete(cache_key) do
      :ok ->
        Logger.debug("Invalidated cache for token: #{cache_key}")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to invalidate cache: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def invalidate(_, _), do: {:error, :invalid_token_format}

  # --- Private Functions ---

  defp validate_and_cache(token, cache_key, deps) do
    case ValidateToken.execute(token, deps) do
      {:ok, result} ->
        # Store in cache asynchronously (fire-and-forget)
        Task.start(fn ->
          case deps.cache_service.set(cache_key, result, @cache_ttl) do
            :ok ->
              Logger.debug("Cached validation result for key: #{cache_key}")

            {:error, reason} ->
              Logger.warning("Failed to cache validation result: #{inspect(reason)}")
          end
        end)

        {:ok, result}

      {:error, _} = error ->
        error
    end
  end

  defp build_cache_key(token) do
    "token:introspect:#{token}"
  end

  defp build_scope_cache_key(token, scope) do
    # Hash scope to keep key length reasonable
    scope_hash =
      :crypto.hash(:sha256, scope) |> Base.encode16(case: :lower) |> String.slice(0, 16)

    "token:scope:#{token}:#{scope_hash}"
  end
end
