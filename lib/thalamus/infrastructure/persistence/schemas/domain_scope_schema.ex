defmodule Thalamus.Infrastructure.Persistence.Schemas.DomainScopeSchema do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "domain_scopes" do
    field :domain, :string
    field :scope, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end
end
