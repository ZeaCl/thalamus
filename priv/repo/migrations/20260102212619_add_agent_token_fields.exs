defmodule Thalamus.Repo.Migrations.AddAgentTokenFields do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      # Agent Identity
      # "autonomous" | "supervised" | "ephemeral"
      add :agent_type, :string
      add :delegated_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :delegation_chain, {:array, :binary_id}, default: []

      # Task Scoping
      # External task identifier
      add :task_id, :string
      # "file_read" | "db_write" | etc.
      add :task_type, :string
      # Subset of scopes
      add :task_scopes, {:array, :string}, default: []
      # Operation limit (null = unlimited)
      add :max_operations, :integer
      # Current operation count
      add :operations_count, :integer, default: 0
      # Auto-revoke when max_operations reached
      add :expires_on_completion, :boolean, default: false

      # Attestation (Compliance)
      # Human-readable intent
      add :intent_description, :text
      # Orchestrator instance ID
      add :orchestrator_id, :string
      # "production" | "staging" | "dev"
      add :environment, :string
    end

    # Indexes for common queries
    create index(:tokens, [:task_id])
    create index(:tokens, [:delegated_by_user_id])
    create index(:tokens, [:agent_type])
    create index(:tokens, [:orchestrator_id])

    # Composite index for cleanup queries
    create index(:tokens, [:agent_type, :expires_at])
  end
end
