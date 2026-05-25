defmodule Thalamus.Infrastructure.Persistence.Migrations.AddEntityIdToUserDomainRoles do
  use Ecto.Migration

  def up do
    alter table(:user_domain_roles) do
      add :entity_id, :string, null: true
    end
  end

  def down do
    alter table(:user_domain_roles) do
      remove :entity_id
    end
  end
end
