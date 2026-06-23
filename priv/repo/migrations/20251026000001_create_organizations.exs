defmodule Thalamus.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :owner_email, :string
      add :status, :string, null: false, default: "trial"
      add :verified, :boolean, default: false, null: false

      # Plan fields
      add :plan_type, :string, null: false, default: "free"
      add :max_users, :integer, null: false
      add :max_api_calls_per_month, :integer, null: false
      add :mfa_required, :boolean, default: false, null: false
      add :sso_enabled, :boolean, default: false, null: false
      add :audit_logs_retention_days, :integer, null: false, default: 30
      add :support_level, :string, null: false, default: "community"

      # Usage tracking
      add :current_user_count, :integer, default: 0, null: false
      add :api_calls_current_month, :integer, default: 0, null: false
      add :api_calls_reset_at, :utc_datetime, null: false

      # Members as JSONB array
      add :members, {:array, :map}, default: [], null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:name])
    create index(:organizations, [:status])
    create index(:organizations, [:plan_type])
    create index(:organizations, [:verified])
  end
end
