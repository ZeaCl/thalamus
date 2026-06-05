defmodule Thalamus.Domain.Entities.Secret do
  @moduledoc """
  Represents an encrypted secret (like a 3rd party API key) owned by a user or organization.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "secrets" do
    field :owner_type, :string # 'user' or 'organization'
    field :owner_id, :binary_id
    field :provider, :string
    field :name, :string
    
    # We use our Cloak Encrypted Binary field for transparent encryption
    field :encrypted_value, Thalamus.Encrypted.Binary
    
    # Virtual field to pass the plain value when creating/updating
    field :value, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [:owner_type, :owner_id, :provider, :name, :value])
    |> validate_required([:owner_type, :owner_id, :provider, :name])
    |> validate_inclusion(:owner_type, ["user", "organization"])
    |> put_encrypted_value()
  end

  # If a plain text value is provided, put it into the encrypted_value field so cloak encrypts it
  defp put_encrypted_value(changeset) do
    case get_change(changeset, :value) do
      nil -> changeset
      plain_text ->
        put_change(changeset, :encrypted_value, plain_text)
    end
  end
end
