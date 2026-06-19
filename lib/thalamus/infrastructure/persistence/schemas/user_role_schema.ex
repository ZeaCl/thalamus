defmodule Thalamus.Infrastructure.Persistence.Schemas.UserRoleSchema do
  @moduledoc """
  Ecto schema for UserRole join table.

  Represents the many-to-many relationship between users and roles.

  SOLID Principles:
  - Single Responsibility: Only handles user-role association mapping
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, RoleSchema}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_roles" do
    belongs_to :user, UserSchema
    belongs_to :role, RoleSchema
    field :assigned_by, :binary_id
    field :assigned_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating a user-role assignment.
  """
  def changeset(user_role \\ %__MODULE__{}, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :assigned_by, :assigned_at])
    |> validate_required([:user_id, :role_id])
    |> put_timestamp_if_missing()
    |> unique_constraint([:user_id, :role_id],
      name: :user_roles_user_id_role_id_index,
      message: "user already has this role assigned"
    )
  end

  defp put_timestamp_if_missing(changeset) do
    case get_field(changeset, :assigned_at) do
      nil -> put_change(changeset, :assigned_at, DateTime.truncate(DateTime.utc_now(), :second))
      _ -> changeset
    end
  end
end
