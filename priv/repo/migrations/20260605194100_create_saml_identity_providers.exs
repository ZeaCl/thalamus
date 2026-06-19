defmodule Thalamus.Repo.Migrations.CreateSamlIdentityProviders do
  use Ecto.Migration

  def up do
    create table(:saml_identity_providers, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id, references(:organizations, type: :uuid, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :idp_entity_id, :string, null: false
      add :idp_sso_url, :string, null: false
      add :idp_slo_url, :string
      add :idp_certificate, :text, null: false
      add :sp_entity_id, :string
      add :idp_metadata_xml, :text
      add :enabled, :boolean, default: true, null: false
      add :force_saml, :boolean, default: false, null: false
      add :jit_provisioning, :boolean, default: true, null: false
      add :allowed_domains, {:array, :string}, default: []
      add :attribute_mapping, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saml_identity_providers, [:organization_id])
    create index(:saml_identity_providers, [:enabled])
  end

  def down do
    drop table(:saml_identity_providers)
  end
end
