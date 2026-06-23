defmodule Thalamus.Infrastructure.Persistence.Migrations.CreateDomainScopes do
  use Ecto.Migration

  def up do
    create table(:domain_scopes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain, :string, null: false
      add :scope, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:domain_scopes, [:domain, :scope])
    create index(:domain_scopes, [:domain])

    create table(:user_domain_roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :organization_id, :binary_id, null: false
      add :domain, :string, null: false
      add :role, :string, null: false
      add :scopes, {:array, :string}, default: [], null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_domain_roles, [:user_id, :organization_id, :domain])
    create unique_index(:user_domain_roles, [:user_id, :organization_id, :domain, :role])

    alter table(:organizations) do
      add :domains, {:array, :string}, default: [], null: false
    end
  end

  def down do
    alter table(:organizations) do
      remove :domains
    end

    drop table(:user_domain_roles)
    drop table(:domain_scopes)
  end
end
