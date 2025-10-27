defmodule Thalamus.Repo.Migrations.CreateOauth2Clients do
  use Ecto.Migration

  def change do
    create table(:oauth2_clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id_string, :string, null: false
      add :name, :string, null: false
      add :client_type, :string, null: false
      add :client_secret, :string
      add :is_active, :boolean, default: true, null: false

      # Arrays
      add :allowed_grant_types, {:array, :string}, default: [], null: false
      add :allowed_scopes, {:array, :string}, default: [], null: false
      add :redirect_uris, {:array, :string}, default: [], null: false

      # Metadata
      add :description, :text
      add :logo_url, :string
      add :terms_of_service_url, :string
      add :privacy_policy_url, :string

      # Security settings
      add :pkce_required, :boolean, default: false, null: false
      add :token_endpoint_auth_method, :string, default: "client_secret_post", null: false

      # Token lifetimes (in seconds)
      add :access_token_lifetime, :integer, default: 3600, null: false
      add :refresh_token_lifetime, :integer, default: 2_592_000, null: false
      add :authorization_code_lifetime, :integer, default: 600, null: false

      # Foreign key to organizations
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:oauth2_clients, [:client_id_string])
    create index(:oauth2_clients, [:organization_id])
    create index(:oauth2_clients, [:is_active])
    create index(:oauth2_clients, [:client_type])
  end
end
