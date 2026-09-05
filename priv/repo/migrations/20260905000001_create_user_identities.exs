defmodule Thalamus.Repo.Migrations.CreateUserIdentities do
  use Ecto.Migration

  def change do
    create table(:user_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :provider_uid, :string, null: false
      add :email, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_identities, [:provider, :provider_uid])
    create unique_index(:user_identities, [:user_id, :provider])
    create index(:user_identities, [:user_id])
    create index(:user_identities, [:email])
  end
end
