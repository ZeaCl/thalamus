defmodule Thalamus.Infrastructure.Persistence.Schemas.UserIdentitySchema do
  @moduledoc """
  Ecto schema for UserIdentity persistence.

  Maps federated external identities to the `user_identities` table.
  Part of the Infrastructure layer.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_identities" do
    field :provider, :string
    field :provider_uid, :string
    field :email, :string
    field :metadata, :map, default: %{}

    belongs_to :user, UserSchema

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a user identity.
  """
  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:id, :user_id, :provider, :provider_uid, :email, :metadata])
    |> validate_required([:user_id, :provider, :provider_uid])
    |> validate_inclusion(:provider, ["google", "apple", "github"])
    |> unique_constraint([:provider, :provider_uid])
    |> unique_constraint([:user_id, :provider])
    |> foreign_key_constraint(:user_id)
  end
end
