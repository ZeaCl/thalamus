defmodule Thalamus.Repo.Migrations.CreateProjectsAndSkillsTables do
  use Ecto.Migration

  def change do
    # 1. Projects Table
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text

      timestamps()
    end
    create unique_index(:projects, [:name])

    # 2. Project Contexts Table (AGENTS.md equivalent)
    create table(:project_contexts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :file_name, :string, null: false
      add :content, :text, null: false
      add :priority, :integer, default: 0, null: false

      timestamps()
    end
    create index(:project_contexts, [:project_id])

    # 3. Agent Skills Table
    create table(:agent_skills, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text, null: false
      add :instructions, :text, null: false
      add :execution_type, :string, null: false # "bash", "http", etc.
      add :execution_endpoint, :string # For HTTP MCP if needed

      timestamps()
    end
    create unique_index(:agent_skills, [:name])
  end
end
