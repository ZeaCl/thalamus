defmodule Thalamus.Repo.Migrations.AddAgentTokensTable do
  use Ecto.Migration

  def change do
    create table(:agent_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      # OAuth2 and multi-tenancy
      add :client_id, references(:oauth2_clients, on_delete: :restrict, type: :uuid), null: false

      add :organization_id, references(:organizations, on_delete: :restrict, type: :uuid),
        null: false

      # Token data
      add :access_token, :string, null: false, size: 255

      # Agent metadata
      add :agent_type, :string, null: false, size: 50
      add :task_id, :uuid, null: false
      add :task_description, :text, null: false
      add :scopes, {:array, :string}, null: false, default: []

      # Delegation tracking
      add :parent_agent_id, references(:agent_tokens, on_delete: :nilify_all, type: :uuid),
        null: true

      add :delegation_chain, :jsonb, null: false, default: "{}"
      add :delegation_depth, :integer, null: false, default: 0
      add :delegator_user_id, :uuid, null: false

      # Token lifecycle
      add :expires_in, :integer, null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime, null: true
      add :revoke_reason, :text, null: true
      add :reason, :text, null: true

      timestamps(type: :utc_datetime)
    end

    # Check constraints
    create constraint(:agent_tokens, :valid_agent_type,
             check: "agent_type IN ('autonomous', 'supervisor', 'tool')"
           )

    create constraint(:agent_tokens, :valid_delegation_depth,
             check: "delegation_depth >= 0 AND delegation_depth < 5"
           )

    # Indexes for performance

    # 1. Partial index on access_token (only active tokens)
    create index(:agent_tokens, [:access_token],
             name: :idx_agent_tokens_access_token,
             where: "revoked_at IS NULL",
             unique: true
           )

    # 2. Index on organization_id for multi-tenant queries
    create index(:agent_tokens, [:organization_id], name: :idx_agent_tokens_organization_id)

    # 3. Partial index on parent_agent_id (only tokens with parents)
    create index(:agent_tokens, [:parent_agent_id],
             name: :idx_agent_tokens_parent_agent_id,
             where: "parent_agent_id IS NOT NULL"
           )

    # 4. Index on task_id for task-based queries
    create index(:agent_tokens, [:task_id], name: :idx_agent_tokens_task_id)

    # 5. Partial index on expires_at (only active tokens)
    create index(:agent_tokens, [:expires_at],
             name: :idx_agent_tokens_expires_at,
             where: "revoked_at IS NULL"
           )

    # 6. GIN index on delegation_chain JSONB for path queries
    execute(
      "CREATE INDEX idx_agent_tokens_delegation_chain ON agent_tokens USING GIN (delegation_chain)",
      "DROP INDEX idx_agent_tokens_delegation_chain"
    )

    # 7. Composite partial index for active token queries (non-revoked)
    # Note: Expiration check is done at application level
    create index(:agent_tokens, [:client_id, :organization_id],
             name: :idx_agent_tokens_active,
             where: "revoked_at IS NULL"
           )
  end
end
