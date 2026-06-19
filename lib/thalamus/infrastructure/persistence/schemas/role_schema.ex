defmodule Thalamus.Infrastructure.Persistence.Schemas.RoleSchema do
  @moduledoc """
  Ecto schema for Role persistence.

  Maps the Role domain entity to the database.

  SOLID Principles:
  - Single Responsibility: Only handles database mapping
  - Dependency Inversion: Domain entities don't depend on this schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{OrganizationSchema, UserRoleSchema}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "roles" do
    field :name, :string
    field :description, :string
    field :scopes, {:array, :string}, default: []

    belongs_to :organization, OrganizationSchema
    has_many :user_roles, UserRoleSchema, foreign_key: :role_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a role.
  """
  def changeset(role \\ %__MODULE__{}, attrs) do
    role
    |> cast(attrs, [:name, :description, :scopes, :organization_id])
    |> validate_required([:name, :organization_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_scopes()
    |> unique_constraint([:organization_id, :name],
      name: :roles_organization_id_name_index,
      message: "role name must be unique within organization"
    )
  end

  defp validate_scopes(changeset) do
    case get_change(changeset, :scopes) do
      nil ->
        changeset

      scopes when is_list(scopes) ->
        if Enum.all?(scopes, &valid_scope_format?/1) do
          changeset
        else
          add_error(changeset, :scopes, "contains invalid scope format")
        end

      _ ->
        add_error(changeset, :scopes, "must be a list of strings")
    end
  end

  # Validates scope format: ^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){0,3}$
  defp valid_scope_format?(scope) when is_binary(scope) do
    String.match?(scope, ~r/^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){0,3}$/) and
      String.length(scope) <= 128
  end

  defp valid_scope_format?(_), do: false
end
