defmodule Thalamus.Repo.Migrations.AddOwnerEmailToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add_if_not_exists :owner_email, :string
    end
  end
end
