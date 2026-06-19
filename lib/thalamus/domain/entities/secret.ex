defmodule Thalamus.Domain.Entities.Secret do
  @moduledoc """
  Represents an encrypted secret (like a 3rd party API key) owned by a user or organization.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "secrets" do
    # 'user' or 'organization'
    field :owner_type, :string
    field :owner_id, :binary_id
    field :provider, :string
    field :name, :string

    # We use our Cloak Encrypted Binary field for transparent encryption
    field :value, Thalamus.Encrypted.Binary, source: :encrypted_value

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [:owner_type, :owner_id, :provider, :name, :value])
    |> validate_required([:owner_type, :owner_id, :provider, :name, :value])
    |> validate_inclusion(:owner_type, ["user", "organization"])
  end
end
