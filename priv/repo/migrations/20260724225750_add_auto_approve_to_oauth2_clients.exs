defmodule Thalamus.Repo.Migrations.AddAutoApproveToOauth2Clients do
  use Ecto.Migration

  def up do
    alter table(:oauth2_clients) do
      add :auto_approve, :boolean, default: false, null: false
    end

    # Mark existing first-party clients as auto_approve
    execute """
    UPDATE oauth2_clients SET auto_approve = true
    WHERE client_id_string IN (
      'platform_web',
      'thalamus_cli',
      '59991e63-852c-44e5-aee1-a761ec76eaea',
      'internal_login'
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
