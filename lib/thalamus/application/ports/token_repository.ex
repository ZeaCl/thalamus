defmodule Thalamus.Application.Ports.TokenRepository do
  @moduledoc """
  Repository port (interface) for OAuth2 token storage and retrieval.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for token operations
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.ValueObjects.{UserId, ClientId}

  @type token_type :: :access_token | :refresh_token | :authorization_code
  @type token_data :: %{
          token: String.t(),
          type: token_type(),
          user_id: UserId.t() | nil,
          client_id: ClientId.t(),
          scopes: [String.t()],
          expires_at: DateTime.t(),
          revoked: boolean(),
          created_at: DateTime.t()
        }

  @callback store(token_data()) :: :ok | {:error, term()}

  @callback find(String.t()) :: {:ok, token_data()} | {:error, :not_found}

  @callback revoke(String.t()) :: :ok | {:error, term()}

  @callback revoke_all_for_user(UserId.t()) :: :ok | {:error, term()}

  @callback revoke_all_for_client(ClientId.t()) :: :ok | {:error, term()}

  @callback cleanup_expired() :: {:ok, non_neg_integer()} | {:error, term()}

  @callback find_by_user(UserId.t()) :: {:ok, [token_data()]} | {:error, term()}
end
