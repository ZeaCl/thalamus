defmodule Thalamus.Repo.Migrations.CreatePersonalAccessTokens do
  use Ecto.Migration

  def change do
    create table(:personal_access_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token_hash, :string, null: false
      add :token_prefix, :string, null: false, size: 20
      add :name, :string, null: false
      add :scopes, {:array, :string}, default: [], null: false
      add :is_active, :boolean, default: true, null: false
      add :expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:personal_access_tokens, [:token_prefix])
    create index(:personal_access_tokens, [:user_id])
    create index(:personal_access_tokens, [:organization_id])
    create index(:personal_access_tokens, [:is_active])
  end
end
