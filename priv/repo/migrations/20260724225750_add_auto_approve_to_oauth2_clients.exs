defmodule Thalamus.Repo.Migrations.AddAutoApproveToOauth2Clients do
  use Ecto.Migration

  def up do
    alter table(:oauth2_clients) do
      add :auto_approve, :boolean, default: false, null: false
    end

    # Mark existing first-party clients as auto_approve.
    # Only clients that go through the authorization_code flow are relevant.
    # internal_login uses password/client_credentials grants — auto_approve has no effect.
    # cerebelum_service uses client_credentials (M2M) — same.
    execute """
    UPDATE oauth2_clients SET auto_approve = true
    WHERE client_id_string IN (
      'platform_web',
      'thalamus_cli'
    )
    OR client_id_string LIKE 'app_%'
    """
  end

  def down do
    alter table(:oauth2_clients) do
      remove :auto_approve
    end
  end
end
