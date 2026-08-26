defmodule Thalamus.Repo.Migrations.CreateEnvironmentsTable do
  use Ecto.Migration

  def change do
    create table(:environments, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :slug, :string, null: false
      add :name, :string, null: false
      add :type, :string, default: "development", null: false
      add :is_default, :boolean, default: false, null: false
      add :status, :string, default: "active", null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:environments, [:organization_id, :slug],
             name: :idx_environments_org_slug
           )

    create unique_index(:environments, [:organization_id],
             where: "is_default = true",
             name: :idx_single_default_env_per_org
           )

    create index(:environments, [:organization_id, :status], name: :idx_environments_org_status)

    # Data migration: backfill default 'production' environment for existing organizations
    execute(
      """
      INSERT INTO environments (id, organization_id, slug, name, type, is_default, status, inserted_at, updated_at)
      SELECT gen_random_uuid(), id, 'production', 'Producción', 'production', true, 'active', NOW(), NOW()
      FROM organizations
      ON CONFLICT (organization_id, slug) DO NOTHING;
      """,
      """
      DELETE FROM environments WHERE slug = 'production' AND is_default = true;
      """
    )
  end
end
