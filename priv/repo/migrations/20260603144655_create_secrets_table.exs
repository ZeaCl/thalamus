defmodule Thalamus.Repo.Migrations.CreateSecretsTable do
  use Ecto.Migration

  def change do
    create table(:secrets, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :owner_type, :string, null: false # 'user' or 'organization'
      add :owner_id, :uuid, null: false
      add :provider, :string, null: false   # e.g., 'google_stitch', 'openai'
      add :name, :string, null: false       # User-friendly name
      add :encrypted_value, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:secrets, [:owner_type, :owner_id])
    create index(:secrets, [:provider])
  end
end
