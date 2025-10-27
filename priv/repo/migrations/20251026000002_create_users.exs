defmodule Thalamus.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :status, :string, null: false, default: "pending_verification"
      add :verified_at, :utc_datetime
      add :last_login_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0, null: false
      add :locked_until, :utc_datetime

      # MFA methods as JSONB array
      add :mfa_methods, {:array, :map}, default: [], null: false

      # Foreign key to organizations
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:status])
    create index(:users, [:organization_id])
    create index(:users, [:verified_at])
    create index(:users, [:last_login_at])
    create index(:users, [:locked_until])
  end
end
