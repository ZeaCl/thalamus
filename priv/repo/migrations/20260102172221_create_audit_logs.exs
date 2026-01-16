defmodule Thalamus.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :nilify_all)
      add :client_id, references(:oauth2_clients, type: :binary_id, on_delete: :nilify_all)

      # Event metadata
      add :metadata, :map, default: %{}
      add :ip_address, :string
      add :user_agent, :text
      add :request_id, :string

      # Context
      add :environment, :string
      add :node, :string

      # Timestamps
      add :inserted_at, :utc_datetime, null: false
    end

    # Indexes for common queries
    create index(:audit_logs, [:event_type])
    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:organization_id])
    create index(:audit_logs, [:client_id])
    create index(:audit_logs, [:inserted_at])
    create index(:audit_logs, [:ip_address])

    # Composite index for time-based queries by user
    create index(:audit_logs, [:user_id, :inserted_at])
    create index(:audit_logs, [:organization_id, :inserted_at])
  end
end
