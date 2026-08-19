defmodule Thalamus.Repo.Migrations.AddParentUserIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :parent_user_id,
          references(:users, column: :id, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:users, [:parent_user_id])
    create index(:users, [:organization_id, :parent_user_id])
  end
end
