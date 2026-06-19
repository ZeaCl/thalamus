defmodule Thalamus.Infrastructure.Persistence.Schemas.UserDomainRoleSchema do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_domain_roles" do
    field :user_id, :binary_id
    field :organization_id, :binary_id
    field :domain, :string
    field :role, :string
    field :scopes, {:array, :string}, default: []

    timestamps(type: :utc_datetime)
  end
end
