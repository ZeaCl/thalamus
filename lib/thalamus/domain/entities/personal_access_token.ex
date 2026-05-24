defmodule Thalamus.Domain.Entities.PersonalAccessToken do
  @moduledoc """
  PersonalAccessToken Entity - Represents a developer's personal access token.

  PATs allow users (especially developers and AI agents) to authenticate
  with the CLI and API using standard Bearer token authentication.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          token_hash: String.t(),
          token_prefix: String.t(),
          name: String.t(),
          scopes: [String.t()],
          is_active: boolean(),
          expires_at: DateTime.t() | nil,
          last_used_at: DateTime.t() | nil,
          user_id: String.t(),
          organization_id: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :token_hash,
    :token_prefix,
    :name,
    :scopes,
    :is_active,
    :expires_at,
    :last_used_at,
    :user_id,
    :organization_id,
    :created_at,
    :updated_at
  ]

  @valid_scopes [
    "openid",
    "profile",
    "email",
    "zea:read",
    "zea:write"
  ]

  @doc """
  Creates a new PersonalAccessToken entity.
  """
  def new(attrs) do
    id = Map.get(attrs, :id) || Map.get(attrs, "id")
    token_hash = Map.get(attrs, :token_hash) || Map.get(attrs, "token_hash")
    token_prefix = Map.get(attrs, :token_prefix) || Map.get(attrs, "token_prefix")
    name = Map.get(attrs, :name) || Map.get(attrs, "name")
    user_id = Map.get(attrs, :user_id) || Map.get(attrs, "user_id")
    organization_id = Map.get(attrs, :organization_id) || Map.get(attrs, "organization_id")

    if id && token_hash && token_prefix && name && user_id && organization_id do
      scopes = Map.get(attrs, :scopes) || Map.get(attrs, "scopes") || []
      now = DateTime.truncate(DateTime.utc_now(), :second)

      {:ok,
       %__MODULE__{
         id: id,
         token_hash: token_hash,
         token_prefix: token_prefix,
         name: name,
         scopes: scopes,
         is_active: Map.get(attrs, :is_active, true),
         expires_at: Map.get(attrs, :expires_at),
         last_used_at: Map.get(attrs, :last_used_at),
         user_id: user_id,
         organization_id: organization_id,
         created_at: Map.get(attrs, :created_at, now),
         updated_at: Map.get(attrs, :updated_at, now)
       }}
    else
      {:error, :missing_required_fields}
    end
  end

  @doc """
  Checks if the token has expired.
  """
  def expired?(%__MODULE__{expires_at: nil}), do: false

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if the token is active and not expired.
  """
  def valid?(%__MODULE__{is_active: false}), do: false

  def valid?(%__MODULE__{} = pat) do
    not expired?(pat)
  end

  @doc """
  Returns the list of valid scopes for PATs.
  """
  def valid_scopes, do: @valid_scopes
end
