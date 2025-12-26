defmodule Thalamus.Repo.Migrations.UpdateAdminApiKeyPrefixLength do
  use Ecto.Migration

  def change do
    # Modify key_prefix column from VARCHAR(12) to VARCHAR(13)
    alter table(:admin_api_keys) do
      modify :key_prefix, :string, size: 13
    end
  end
end
