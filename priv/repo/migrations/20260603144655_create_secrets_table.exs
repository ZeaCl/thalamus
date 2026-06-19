defmodule Thalamus.Repo.Migrations.CreateSecretsTable do
  use Ecto.Migration

  def change do
    create table(:secrets, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      # 'user' or 'organization'
      add :owner_type, :string, null: false
      add :owner_id, :uuid, null: false
      # e.g., 'google_stitch', 'openai'
      add :provider, :string, null: false
      # User-friendly name
      add :name, :string, null: false
      add :encrypted_value, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:secrets, [:owner_type, :owner_id])
    create index(:secrets, [:provider])
  end
end
