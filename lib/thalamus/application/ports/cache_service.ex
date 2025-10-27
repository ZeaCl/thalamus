defmodule Thalamus.Application.Ports.CacheService do
  @moduledoc """
  Port (interface) for caching operations.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for caching
  - Dependency Inversion: Application layer depends on this abstraction
  """

  @type key :: String.t()
  @type value :: term()
  @type ttl :: pos_integer()

  @callback get(key()) :: {:ok, value()} | {:error, :not_found}
  @callback set(key(), value(), ttl()) :: :ok | {:error, term()}
  @callback delete(key()) :: :ok | {:error, term()}
  @callback exists?(key()) :: boolean()
  @callback increment(key(), pos_integer()) :: {:ok, integer()} | {:error, term()}
  @callback expire(key(), ttl()) :: :ok | {:error, term()}
end
