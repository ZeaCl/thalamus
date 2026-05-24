defmodule Thalamus.Repo.Migrations.AddRbacTables do
  use Ecto.Migration

  def up do
    # Create roles table
    create table(:roles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :organization_id, references(:organizations, type: :uuid, on_delete: :delete_all),
        null: false

      add :name, :string, size: 100, null: false
      add :description, :text
      add :scopes, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    # Create user_roles join table
    create table(:user_roles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false
      add :assigned_by, references(:users, type: :uuid, on_delete: :nilify_all)
      add :assigned_at, :utc_datetime, null: false, default: fragment("NOW()")

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Indexes for roles table
    create unique_index(:roles, [:organization_id, :name],
             name: :roles_organization_id_name_index
           )

    create index(:roles, [:organization_id], name: :roles_organization_id_index)

    # Indexes for user_roles table
    create unique_index(:user_roles, [:user_id, :role_id],
             name: :user_roles_user_id_role_id_index
           )

    create index(:user_roles, [:user_id], name: :user_roles_user_id_index)
    create index(:user_roles, [:role_id], name: :user_roles_role_id_index)

    # Check constraints
    execute("""
      ALTER TABLE roles
      ADD CONSTRAINT roles_name_length
      CHECK (char_length(name) >= 1 AND char_length(name) <= 100)
    """)

    execute("""
      ALTER TABLE roles
      ADD CONSTRAINT roles_description_length
      CHECK (description IS NULL OR char_length(description) <= 500)
    """)
  end

  def down do
    # Drop constraints
    execute("ALTER TABLE roles DROP CONSTRAINT IF EXISTS roles_description_length")
    execute("ALTER TABLE roles DROP CONSTRAINT IF EXISTS roles_name_length")

    # Drop indexes (automatically dropped with tables, but explicit for clarity)
    drop_if_exists index(:user_roles, [:role_id], name: :user_roles_role_id_index)
    drop_if_exists index(:user_roles, [:user_id], name: :user_roles_user_id_index)

    drop_if_exists unique_index(:user_roles, [:user_id, :role_id],
                     name: :user_roles_user_id_role_id_index
                   )

    drop_if_exists index(:roles, [:organization_id], name: :roles_organization_id_index)

    drop_if_exists unique_index(:roles, [:organization_id, :name],
                     name: :roles_organization_id_name_index
                   )

    # Drop tables (CASCADE handled by foreign keys)
    drop table(:user_roles)
    drop table(:roles)
  end
end
