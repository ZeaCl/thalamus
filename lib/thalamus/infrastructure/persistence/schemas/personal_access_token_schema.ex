defmodule Thalamus.Infrastructure.Persistence.Schemas.PersonalAccessTokenSchema do
  @moduledoc """
  Ecto schema for PersonalAccessToken persistence.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OrganizationSchema}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "personal_access_tokens" do
    field :token_hash, :string
    field :token_prefix, :string
    field :name, :string
    field :scopes, {:array, :string}, default: []
    field :is_active, :boolean, default: true
    field :expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec

    belongs_to :user, UserSchema
    belongs_to :organization, OrganizationSchema

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating a new Personal Access Token.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :token_hash,
      :token_prefix,
      :name,
      :scopes,
      :is_active,
      :expires_at,
      :user_id,
      :organization_id
    ])
    |> validate_required([:token_hash, :token_prefix, :name, :user_id, :organization_id])
    |> validate_length(:name, min: 3, max: 255)
    |> validate_length(:token_prefix, is: 16)
    |> unique_constraint(:token_prefix)
  end

  @doc """
  Changeset for updating a Personal Access Token.
  """
  def update_changeset(pat, attrs) do
    pat
    |> cast(attrs, [:name, :scopes, :is_active, :expires_at, :last_used_at])
  end

  @doc """
  Changeset for marking a token as used.
  """
  def mark_used_changeset(pat) do
    pat
    |> change(last_used_at: DateTime.utc_now())
  end
end
