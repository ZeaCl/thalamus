defmodule Thalamus.Infrastructure.Adapters.RedisCacheAdapter do
  @moduledoc """
  Redis implementation of the CacheService port.

  This adapter provides caching functionality using Redis.
  It implements the CacheService behaviour defined in the Application layer.

  Use cases:
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

  # Note: This assumes Redix or a similar Redis client is configured
  # In production, you would configure this in config/config.exs

  @impl true
  def get(key) when is_binary(key) do
    case redis_command(["GET", key]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, decode_value(value)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def set(key, value, ttl) when is_binary(key) and is_integer(ttl) do
    encoded_value = encode_value(value)
    command = ["SETEX", key, to_string(ttl), encoded_value]

    case redis_command(command) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key) when is_binary(key) do
    case redis_command(["DEL", key]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def exists?(key) when is_binary(key) do
    case redis_command(["EXISTS", key]) do
      {:ok, 1} -> true
      {:ok, 0} -> false
      {:error, _reason} -> false
    end
  end

  @impl true
  def increment(key, amount \\ 1) when is_binary(key) and is_integer(amount) do
    case redis_command(["INCRBY", key, to_string(amount)]) do
      {:ok, new_value} when is_integer(new_value) -> {:ok, new_value}
      {:ok, new_value} when is_binary(new_value) -> {:ok, String.to_integer(new_value)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper function (not part of behaviour)
  def decrement(key, amount \\ 1) when is_binary(key) and is_integer(amount) do
    case redis_command(["DECRBY", key, to_string(amount)]) do
      {:ok, new_value} when is_integer(new_value) -> {:ok, new_value}
      {:ok, new_value} when is_binary(new_value) -> {:ok, String.to_integer(new_value)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def expire(key, ttl) when is_binary(key) and is_integer(ttl) do
    case redis_command(["EXPIRE", key, to_string(ttl)]) do
      {:ok, 1} -> :ok
      {:ok, 0} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper function (not part of behaviour)
  def ttl(key) when is_binary(key) do
    case redis_command(["TTL", key]) do
      {:ok, -2} -> {:error, :not_found}
      {:ok, -1} -> {:ok, :no_expiration}
      {:ok, seconds} when is_integer(seconds) -> {:ok, seconds}
      {:ok, seconds} when is_binary(seconds) -> {:ok, String.to_integer(seconds)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper function (not part of behaviour)
  def flush_all do
    case redis_command(["FLUSHDB"]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp redis_command(command) do
    # In a real implementation, this would use Redix or similar
    # For now, we'll provide a mock implementation that can be swapped

    case Application.get_env(:thalamus, :redis_adapter, :mock) do
      :mock ->
        # Mock implementation for testing
        mock_redis_command(command)

      :redix ->
        # Real Redis implementation
        # Redix.command(@redis_name, command)
        {:error, :not_configured}
    end
  end

  # Mock implementation for development/testing
  defp mock_redis_command(["GET", _key]), do: {:ok, nil}
  defp mock_redis_command(["SET" | _]), do: {:ok, "OK"}
  defp mock_redis_command(["SETEX" | _]), do: {:ok, "OK"}
  defp mock_redis_command(["DEL", _key]), do: {:ok, 1}
  defp mock_redis_command(["EXISTS", _key]), do: {:ok, 0}
  defp mock_redis_command(["INCRBY", _key, amount]), do: {:ok, String.to_integer(amount)}
  defp mock_redis_command(["DECRBY", _key, amount]), do: {:ok, -String.to_integer(amount)}
  defp mock_redis_command(["EXPIRE", _key, _ttl]), do: {:ok, 1}
  defp mock_redis_command(["TTL", _key]), do: {:ok, -2}
  defp mock_redis_command(["FLUSHDB"]), do: {:ok, "OK"}
  defp mock_redis_command(_), do: {:error, :unknown_command}

  defp encode_value(value) when is_binary(value), do: value
  defp encode_value(value), do: Jason.encode!(value)

  defp decode_value(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      {:error, _} -> value
    end
  end

  defp decode_value(value), do: value
end
