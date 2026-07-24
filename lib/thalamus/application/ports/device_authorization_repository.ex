defmodule Thalamus.Application.Ports.DeviceAuthorizationRepository do
  @moduledoc """
  Repository port (interface) for OAuth2 Device Authorization storage.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for device authorization operations
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.Entities.DeviceAuthorization

  @type device_authorization :: DeviceAuthorization.t()

  @callback store(device_authorization()) :: {:ok, device_authorization()} | {:error, term()}

  @callback find_by_device_code(String.t()) ::
              {:ok, device_authorization()} | {:error, :not_found}

  @callback find_by_user_code(String.t()) :: {:ok, device_authorization()} | {:error, :not_found}

  @callback authorize(device_authorization(), user_id :: String.t()) ::
              {:ok, device_authorization()} | {:error, term()}

  @callback record_poll(device_authorization()) ::
              {:ok, device_authorization()} | {:error, term()}

  @callback expire(device_authorization()) :: {:ok, device_authorization()} | {:error, term()}

  @callback cleanup_expired() :: {:ok, non_neg_integer()} | {:error, term()}
end
