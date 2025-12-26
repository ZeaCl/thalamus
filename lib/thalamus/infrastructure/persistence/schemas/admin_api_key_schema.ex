defmodule Thalamus.Infrastructure.Persistence.Schemas.AdminApiKeySchema do
  @moduledoc """
  Ecto schema for AdminApiKey persistence.

  Maps the AdminApiKey domain entity to the database.
  This is part of the Infrastructure layer and should only be used by repositories.

  SOLID Principles Applied:
  - Single Responsibility: Only handles database mapping
  - Dependency Inversion: Domain entities don't depend on this schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "admin_api_keys" do
    field :key_hash, :string
    field :key_prefix, :string
    field :name, :string
    field :description, :string
    field :scopes, {:array, :string}, default: []
    field :is_active, :boolean, default: true
    field :expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec

    # Relationships
    belongs_to :created_by_user, UserSchema, foreign_key: :created_by_user_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating a new Admin API Key.

  ## Required fields
  - key_hash
  - key_prefix
  - name

  ## Optional fields
  - description
  - scopes
  - is_active
  - expires_at
  - created_by_user_id
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :key_hash,
      :key_prefix,
      :name,
      :description,
      :scopes,
      :is_active,
      :expires_at,
      :created_by_user_id
    ])
    |> validate_required([:key_hash, :key_prefix, :name])
    |> validate_length(:name, min: 3, max: 255)
    |> validate_length(:key_prefix, is: 13)
    |> validate_scopes()
    |> unique_constraint(:key_prefix)
  end

  @doc """
  Changeset for updating an Admin API Key.

  Allows updating: description, scopes, is_active, expires_at, last_used_at
  """
  def update_changeset(admin_api_key, attrs) do
    admin_api_key
    |> cast(attrs, [
      :description,
      :scopes,
      :is_active,
      :expires_at,
      :last_used_at
    ])
    |> validate_scopes()
  end

  @doc """
  Changeset for rotating an Admin API Key.

  Updates the key_hash and key_prefix to new values.
  """
  def rotate_changeset(admin_api_key, attrs) do
    admin_api_key
    |> cast(attrs, [:key_hash, :key_prefix])
    |> validate_required([:key_hash, :key_prefix])
    |> validate_length(:key_prefix, is: 13)
    |> unique_constraint(:key_prefix)
  end

  @doc """
  Changeset for updating last_used_at timestamp.
  """
  def mark_used_changeset(admin_api_key) do
    admin_api_key
    |> change(last_used_at: DateTime.utc_now())
  end

  # Private validation functions

  defp validate_scopes(changeset) do
    validate_change(changeset, :scopes, fn :scopes, scopes ->
      valid_scopes = [
        "clients:read",
        "clients:write",
        "clients:delete",
        "users:read",
        "users:write",
        "organizations:read",
        "organizations:write",
        "corpus:read",
        "corpus:write"
      ]

      invalid_scopes = Enum.reject(scopes, fn scope -> scope in valid_scopes end)

      if Enum.empty?(invalid_scopes) do
        []
      else
        [scopes: "contains invalid scopes: #{Enum.join(invalid_scopes, ", ")}"]
      end
    end)
  end
end
