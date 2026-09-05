defmodule Thalamus.Domain.Entities.UserIdentity do
  @moduledoc """
  Entity representing an external federated identity linked to a user.

  Supports social identity federation (Google, Apple, GitHub) where
  a single user can have multiple external identities linked to their account.

  SOLID:
  - Single Responsibility: Manages federated identity entity state and validation.
  """

  @type provider :: String.t()

  @type t :: %__MODULE__{
          id: binary() | nil,
          user_id: binary(),
          provider: provider(),
          provider_uid: String.t(),
          email: String.t() | nil,
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :user_id,
    :provider,
    :provider_uid,
    :email,
    metadata: %{},
    inserted_at: nil,
    updated_at: nil
  ]

  @valid_providers ["google", "apple", "github"]

  @doc """
  Creates a new UserIdentity with validation.
  """
  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    user_id = Map.get(attrs, :user_id) || Map.get(attrs, "user_id")
    provider = Map.get(attrs, :provider) || Map.get(attrs, "provider")
    provider_uid = Map.get(attrs, :provider_uid) || Map.get(attrs, "provider_uid")

    with :ok <-
           validate_required(%{user_id: user_id, provider: provider, provider_uid: provider_uid}),
         :ok <- validate_provider(provider) do
      id = Map.get(attrs, :id) || Map.get(attrs, "id") || UUID.uuid4()
      email = Map.get(attrs, :email) || Map.get(attrs, "email")
      metadata = Map.get(attrs, :metadata) || Map.get(attrs, "metadata") || %{}
      now = DateTime.truncate(DateTime.utc_now(), :second)

      {:ok,
       %__MODULE__{
         id: id,
         user_id: user_id,
         provider: to_string(provider),
         provider_uid: to_string(provider_uid),
         email: if(email, do: String.downcase(email), else: nil),
         metadata: metadata,
         inserted_at: Map.get(attrs, :inserted_at) || now,
         updated_at: Map.get(attrs, :updated_at) || now
       }}
    end
  end

  @doc """
  Returns the list of supported social providers.
  """
  @spec supported_providers() :: [String.t()]
  def supported_providers, do: @valid_providers

  @doc """
  Checks if a provider string is supported.
  """
  @spec valid_provider?(String.t() | atom()) :: boolean()
  def valid_provider?(provider) when is_atom(provider) do
    valid_provider?(Atom.to_string(provider))
  end

  def valid_provider?(provider) when is_binary(provider) do
    provider in @valid_providers
  end

  def valid_provider?(_), do: false

  defp validate_required(%{user_id: user_id, provider: provider, provider_uid: provider_uid}) do
    cond do
      is_nil(user_id) or user_id == "" -> {:error, :missing_user_id}
      is_nil(provider) or provider == "" -> {:error, :missing_provider}
      is_nil(provider_uid) or provider_uid == "" -> {:error, :missing_provider_uid}
      true -> :ok
    end
  end

  defp validate_provider(provider) do
    if valid_provider?(provider) do
      :ok
    else
      {:error, {:invalid_provider, provider}}
    end
  end
end
