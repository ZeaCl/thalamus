defmodule Thalamus.Infrastructure.Adapters.RedisCacheAdapter do
  @moduledoc """
  Production Redis cache adapter using Redix.

  Replaces the MOCK implementation with real Redis connectivity.

  This adapter provides caching functionality using Redis.
  It implements the CacheService behaviour defined in the Application layer.

  Use cases:
  - Token introspection caching
  - Session storage
  - Rate limiting counters
  - Temporary token storage
  - MFA code storage (OTP)
  - Device fingerprints

  SOLID Principles Applied:
  - Single Responsibility: Only handles cache operations
  - Dependency Inversion: Implements the port defined by Application layer
  - Interface Segregation: Implements only CacheService interface
  """

  @behaviour Thalamus.Application.Ports.CacheService

  require Logger

  @doc """
  Starts the Redis connection pool.

  Called during application startup.
  """
  def child_spec(_opts) do
    redis_url = Application.get_env(:thalamus, :redis_url, "redis://localhost:6379/0")

    children = [
      {Redix,
       host: parse_host(redis_url),
       port: parse_port(redis_url),
       password: parse_password(redis_url),
       database: parse_database(redis_url),
       name: :redix,
       sync_connect: false,
       exit_on_disconnection: false,
       socket_opts: [:inet6]}
    ]

    %{
      id: __MODULE__,
      start:
        {Supervisor, :start_link,
         [children, [strategy: :one_for_one, name: __MODULE__.Supervisor]]},
      type: :supervisor
    }
  end

  @impl true
  def get(key) when is_binary(key) do
    case redis_command(["GET", key]) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, value} ->
        {:ok, deserialize(value)}

      {:error, reason} ->
        Logger.error("Redis GET failed for key #{key}: #{inspect(reason)}")
        {:error, :cache_unavailable}
    end
  end

  @impl true
  def set(key, value, ttl) when is_binary(key) and is_integer(ttl) do
    serialized = serialize(value)

    case redis_command(["SETEX", key, ttl, serialized]) do
      {:ok, "OK"} ->
        :ok

      {:error, reason} ->
        Logger.error("Redis SET failed for key #{key}: #{inspect(reason)}")
        {:error, :cache_unavailable}
    end
  end

  @impl true
  def delete(key) when is_binary(key) do
    case redis_command(["DEL", key]) do
      {:ok, _count} ->
        :ok

      {:error, reason} ->
        Logger.error("Redis DEL failed for key #{key}: #{inspect(reason)}")
        {:error, :cache_unavailable}
    end
  end

  @impl true
  def exists?(key) when is_binary(key) do
    case redis_command(["EXISTS", key]) do
      {:ok, 1} -> {:ok, true}
      {:ok, 0} -> {:ok, false}
      # Fail open
      {:error, _} -> {:ok, false}
    end
  end

  @impl true
  def increment(key, amount \\ 1) when is_binary(key) and is_integer(amount) do
    case redis_command(["INCRBY", key, amount]) do
      {:ok, new_value} ->
        {:ok, new_value}

      {:error, reason} ->
        Logger.error("Redis INCRBY failed for key #{key}: #{inspect(reason)}")
        {:error, :cache_unavailable}
    end
  end

  @impl true
  def expire(key, ttl) when is_binary(key) and is_integer(ttl) do
    case redis_command(["EXPIRE", key, ttl]) do
      {:ok, 1} -> :ok
      {:ok, 0} -> {:error, :not_found}
      {:error, _} -> {:error, :cache_unavailable}
    end
  end

  # --- Helper Functions (not part of behaviour) ---

  @doc """
  Decrements a counter in Redis.

  Helper function for rate limiting.
  """
  def decrement(key, amount \\ 1) when is_binary(key) and is_integer(amount) do
    case redis_command(["DECRBY", key, amount]) do
      {:ok, new_value} ->
        {:ok, new_value}

      {:error, reason} ->
        Logger.error("Redis DECRBY failed: #{inspect(reason)}")
        {:error, :cache_unavailable}
    end
  end

  @doc """
  Gets the TTL (time to live) of a key in seconds.

  Returns:
  - `{:ok, seconds}` - TTL in seconds
  - `{:ok, :no_expiration}` - Key exists but has no expiration
  - `{:error, :not_found}` - Key doesn't exist
  """
  def ttl(key) when is_binary(key) do
    case redis_command(["TTL", key]) do
      {:ok, -2} -> {:error, :not_found}
      {:ok, -1} -> {:ok, :no_expiration}
      {:ok, seconds} -> {:ok, seconds}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Flushes all keys in the current database.

  WARNING: Use with extreme caution. Only for testing.
  """
  def flush_all do
    case redis_command(["FLUSHDB"]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks if Redis is available and responding.

  Returns `{:ok, "PONG"}` if successful.
  """
  def ping do
    case redis_command(["PING"]) do
      {:ok, "PONG"} -> {:ok, "PONG"}
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Private Functions ---

  defp redis_command(command) do
    case Application.get_env(:thalamus, :redis_adapter, :mock) do
      :mock ->
        # Mock implementation for development/testing
        mock_redis_command(command)

      :redix ->
        # Real Redis implementation
        Redix.command(:redix, command)
    end
  rescue
    error ->
      Logger.error("Redis command failed: #{inspect(error)}")
      {:error, :connection_failed}
  end

  # Mock implementation for development/testing
  defp mock_redis_command(["GET", _key]), do: {:ok, nil}
  defp mock_redis_command(["SET" | _]), do: {:ok, "OK"}
  defp mock_redis_command(["SETEX" | _]), do: {:ok, "OK"}
  defp mock_redis_command(["DEL", _key]), do: {:ok, 1}
  defp mock_redis_command(["EXISTS", _key]), do: {:ok, 0}
  defp mock_redis_command(["INCRBY", _key, amount]), do: {:ok, amount}
  defp mock_redis_command(["DECRBY", _key, amount]), do: {:ok, -amount}
  defp mock_redis_command(["EXPIRE", _key, _ttl]), do: {:ok, 1}
  defp mock_redis_command(["TTL", _key]), do: {:ok, -2}
  defp mock_redis_command(["FLUSHDB"]), do: {:ok, "OK"}
  defp mock_redis_command(["PING"]), do: {:ok, "PONG"}
  defp mock_redis_command(_), do: {:error, :unknown_command}

  defp serialize(value) do
    Jason.encode!(value)
  end

  defp deserialize(binary) do
    Jason.decode!(binary, keys: :atoms)
  rescue
    Jason.DecodeError ->
      # If not JSON, return as-is (for backward compatibility)
      binary
  end

  defp parse_host(url) do
    uri = URI.parse(url)
    uri.host || "localhost"
  end

  defp parse_port(url) do
    uri = URI.parse(url)
    uri.port || 6379
  end

  defp parse_password(url) do
    uri = URI.parse(url)

    if uri.userinfo do
      uri.userinfo |> String.split(":") |> List.last()
    else
      nil
    end
  end

  defp parse_database(url) do
    uri = URI.parse(url)

    if uri.path do
      uri.path |> String.trim_leading("/") |> String.to_integer()
    else
      0
    end
  rescue
    ArgumentError -> 0
  end
end
