defmodule Thalamus.Repo.Migrations.AddOrganizationIdToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:tokens, [:organization_id])
  end
end
