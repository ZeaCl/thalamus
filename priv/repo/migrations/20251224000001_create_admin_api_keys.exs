defmodule Thalamus.Repo.Migrations.CreateAdminApiKeys do
  @moduledoc """
  Creates the admin_api_keys table for managing Admin API Keys.

  Admin API Keys allow external services to authenticate and register
  themselves as OAuth2 clients without manual intervention.
  """

  use Ecto.Migration

  def change do
    create table(:admin_api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key_hash, :string, null: false
      add :key_prefix, :string, null: false, size: 12
      add :name, :string, null: false
      add :description, :text

      # Scopes that this API key can use
      add :scopes, {:array, :string}, default: [], null: false

      # Status and expiration
      add :is_active, :boolean, default: true, null: false
      add :expires_at, :utc_datetime_usec

      # Usage tracking
      add :last_used_at, :utc_datetime_usec

      # Audit trail
      add :created_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for efficient lookups
    create unique_index(:admin_api_keys, [:key_prefix])
    create index(:admin_api_keys, [:is_active])
    create index(:admin_api_keys, [:created_by_user_id])
    create index(:admin_api_keys, [:expires_at])
  end
end
