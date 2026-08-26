defmodule Thalamus.Application.Ports.SecretRepository do
  @moduledoc """
  Port for Secret persistence operations.
  """
  alias Thalamus.Domain.Entities.Secret

  @callback create(attrs :: map()) :: {:ok, Secret.t()} | {:error, term()}
  @callback get(id :: String.t()) :: {:ok, Secret.t()} | {:error, :not_found}
  @callback get_by_owner_and_provider(
              owner_type :: String.t(),
              owner_id :: String.t(),
              provider :: String.t()
            ) :: {:ok, Secret.t()} | {:error, :not_found}
  @callback get_by_owner_provider_and_env(
              owner_type :: String.t(),
              owner_id :: String.t(),
              provider :: String.t(),
              environment_id :: String.t() | nil
            ) :: {:ok, Secret.t()} | {:error, :not_found}
  @callback list_by_owner(owner_type :: String.t(), owner_id :: String.t()) :: [Secret.t()]
  @callback list_by_owner(
              owner_type :: String.t(),
              owner_id :: String.t(),
              environment_id :: String.t() | nil
            ) :: [Secret.t()]
  @callback delete(id :: String.t()) :: {:ok, Secret.t()} | {:error, term()}
end
