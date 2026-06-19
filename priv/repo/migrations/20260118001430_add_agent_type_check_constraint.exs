defmodule Thalamus.Repo.Migrations.AddAgentTypeCheckConstraint do
  use Ecto.Migration

  def up do
    # Add CHECK constraint for agent_type as per 03-tasks.md spec
    # Valid types: 'autonomous', 'supervisor', 'tool'
    execute """
    ALTER TABLE tokens
    ADD CONSTRAINT tokens_agent_type_check
    CHECK (agent_type IS NULL OR agent_type IN ('autonomous', 'supervisor', 'tool'))
    """
  end

  def down do
    execute "ALTER TABLE tokens DROP CONSTRAINT IF EXISTS tokens_agent_type_check"
  end
end
