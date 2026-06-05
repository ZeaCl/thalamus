defmodule Thalamus.Repo.Migrations.AddAgentFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_agent, :boolean, default: false, null: false
      add :agent_config, :jsonb, default: "{}", null: false
    end
  end
end
