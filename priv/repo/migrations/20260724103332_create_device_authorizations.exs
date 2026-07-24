defmodule Thalamus.Repo.Migrations.CreateDeviceAuthorizations do
  use Ecto.Migration

  @moduledoc """
  Creates the device_authorizations table for OAuth2 Device Flow (RFC 8628).

  Stores pending device authorization requests with their
  device_code, user_code, and polling state.
  """

  def up do
    create table(:device_authorizations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :device_code, :string, null: false
      add :user_code, :string, null: false
      add :client_id, references(:oauth2_clients, type: :uuid), null: false
      add :scopes, {:array, :string}, default: []
      add :user_id, references(:users, type: :uuid), null: true
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime, null: false
      add :last_polled_at, :utc_datetime
      add :interval, :integer, null: false, default: 5
      add :authorized_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:device_authorizations, [:device_code])
    create unique_index(:device_authorizations, [:user_code])

    create index(:device_authorizations, [:status])
    create index(:device_authorizations, [:expires_at])
  end

  def down do
    drop table(:device_authorizations)
  end
end
