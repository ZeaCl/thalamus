defmodule Thalamus.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string, null: false
      add :type, :string, null: false
      add :scopes, {:array, :string}, default: [], null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked, :boolean, default: false, null: false
      add :revoked_at, :utc_datetime

      # PKCE support
      add :code_challenge, :string
      add :code_challenge_method, :string

      # Token family for refresh token rotation
      add :token_family_id, :binary_id

      # Foreign keys
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      add :client_id, references(:oauth2_clients, type: :binary_id, on_delete: :delete_all),
        null: false

      # Only created_at, no updated_at
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:tokens, [:token])
    create index(:tokens, [:type])
    create index(:tokens, [:user_id])
    create index(:tokens, [:client_id])
    create index(:tokens, [:expires_at])
    create index(:tokens, [:revoked])
    create index(:tokens, [:token_family_id])

    # Compound index for common queries
    create index(:tokens, [:client_id, :type, :revoked])
    create index(:tokens, [:user_id, :type, :revoked])
  end
end
