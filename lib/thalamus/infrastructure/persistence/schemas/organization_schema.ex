defmodule Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema do
  @moduledoc """
  Ecto schema for Organization persistence.

  Maps the Organization domain entity to the database.
  This is part of the Infrastructure layer and should only be used by repositories.

  SOLID Principles Applied:
  - Single Responsibility: Only handles database mapping
  - Dependency Inversion: Domain entities don't depend on this schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OAuth2ClientSchema}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organizations" do
    field :name, :string
    field :owner_email, :string

    field :status, Ecto.Enum,
      values: [:pending_verification, :trial, :active, :suspended, :inactive, :cancelled]

    field :verified, :boolean, default: false

    # Plan fields (embedded)
    field :plan_type, Ecto.Enum,
      values: [:free, :starter, :professional, :enterprise],
      default: :free

    field :max_users, :integer
    field :max_api_calls_per_month, :integer
    field :mfa_required, :boolean, default: false
    field :sso_enabled, :boolean, default: false
    field :audit_logs_retention_days, :integer, default: 30

    field :support_level, Ecto.Enum,
      values: [:community, :email, :priority, :dedicated, :enterprise]

    # Usage tracking
    field :current_user_count, :integer, default: 0
    field :api_calls_current_month, :integer, default: 0
    field :api_calls_reset_at, :utc_datetime

    # Members stored as JSONB array
    # Each member: %{user_id: uuid, role: atom, joined_at: datetime}
    field :members, {:array, :map}, default: []

    # Domain access
    field :domains, {:array, :string}, default: []

    # Relationships
    has_many :users, UserSchema, foreign_key: :organization_id
    has_many :oauth2_clients, OAuth2ClientSchema, foreign_key: :organization_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new organization.

  ## Required fields
  - name
  - plan_type (defaults to :free)
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :id,
      :name,
      :owner_email,
      :status,
      :verified,
      :plan_type,
      :max_users,
      :max_api_calls_per_month,
      :members,
      :current_user_count,
      :api_calls_current_month,
      :inserted_at,
      :updated_at
    ])
    |> validate_required([:name])
    |> validate_name()
    |> put_plan_defaults()
    |> put_default_values()
  end

  @doc """
  Changeset for updating organization attributes.
  """
  def update_changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :name,
      :owner_email,
      :status,
      :verified,
      :plan_type,
      :max_users,
      :max_api_calls_per_month,
      :current_user_count,
      :api_calls_current_month,
      :members,
      :updated_at
    ])
    |> validate_name()
  end

  @doc """
  Changeset for upgrading/downgrading the plan.
  """
  def change_plan_changeset(organization, new_plan_type) do
    organization
    |> change(%{plan_type: new_plan_type})
    |> put_plan_limits(new_plan_type)
  end

  @doc """
  Changeset for verifying an organization.
  """
  def verify_changeset(organization) do
    organization
    |> change(%{
      verified: true,
      status: :active
    })
  end

  @doc """
  Changeset for suspending an organization.
  """
  def suspend_changeset(organization) do
    organization
    |> change(%{status: :suspended})
  end

  @doc """
  Changeset for reactivating an organization.
  """
  def reactivate_changeset(organization) do
    organization
    |> change(%{status: :active})
  end

  @doc """
  Changeset for adding a member to the organization.
  """
  def add_member_changeset(organization, member_map) do
    existing_members = organization.members || []
    new_members = existing_members ++ [member_map]

    organization
    |> change(%{
      members: new_members,
      current_user_count: length(new_members)
    })
  end

  @doc """
  Changeset for removing a member from the organization.
  """
  def remove_member_changeset(organization, user_id) do
    existing_members = organization.members || []

    new_members = Enum.reject(existing_members, fn member -> member["user_id"] == user_id end)

    organization
    |> change(%{
      members: new_members,
      current_user_count: length(new_members)
    })
  end

  @doc """
  Changeset for updating member role.
  """
  def update_member_role_changeset(organization, user_id, new_role) do
    existing_members = organization.members || []

    new_members =
      Enum.map(existing_members, fn member ->
        if member["user_id"] == user_id do
          Map.put(member, "role", to_string(new_role))
        else
          member
        end
      end)

    organization
    |> change(%{members: new_members})
  end

  @doc """
  Changeset for incrementing API call count.
  """
  def increment_api_calls_changeset(organization) do
    new_count = (organization.api_calls_current_month || 0) + 1

    organization
    |> change(%{api_calls_current_month: new_count})
  end

  @doc """
  Changeset for resetting monthly API call counter.
  """
  def reset_api_calls_changeset(organization) do
    organization
    |> change(%{
      api_calls_current_month: 0,
      api_calls_reset_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  # Private functions

  defp validate_name(changeset) do
    changeset
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
    |> unique_constraint(:name)
  end

  defp put_default_values(changeset) do
    changeset
    |> put_if_missing(:status, :trial)
    |> put_if_missing(:verified, false)
    |> put_if_missing(:current_user_count, 0)
    |> put_if_missing(:api_calls_current_month, 0)
    |> put_if_missing(:api_calls_reset_at, DateTime.truncate(DateTime.utc_now(), :second))
  end

  defp put_if_missing(changeset, field, default) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, default)
      _ -> changeset
    end
  end

  defp put_plan_defaults(changeset) do
    plan_type = get_field(changeset, :plan_type) || :free
    put_plan_limits(changeset, plan_type)
  end

  defp put_plan_limits(changeset, plan_type) do
    limits = get_plan_limits(plan_type)

    changeset
    |> put_change(:max_users, limits.max_users)
    |> put_change(:max_api_calls_per_month, limits.max_api_calls_per_month)
    |> put_change(:mfa_required, limits.mfa_required)
    |> put_change(:sso_enabled, limits.sso_enabled)
    |> put_change(:audit_logs_retention_days, limits.audit_logs_retention_days)
    |> put_change(:support_level, limits.support_level)
  end

  defp get_plan_limits(:free) do
    %{
      max_users: 5,
      max_api_calls_per_month: 10_000,
      mfa_required: false,
      sso_enabled: false,
      audit_logs_retention_days: 7,
      support_level: :community
    }
  end

  defp get_plan_limits(:starter) do
    %{
      max_users: 20,
      max_api_calls_per_month: 100_000,
      mfa_required: false,
      sso_enabled: false,
      audit_logs_retention_days: 30,
      support_level: :email
    }
  end

  defp get_plan_limits(:professional) do
    %{
      max_users: 100,
      max_api_calls_per_month: 1_000_000,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 90,
      support_level: :priority
    }
  end

  defp get_plan_limits(:enterprise) do
    %{
      max_users: 999_999,
      max_api_calls_per_month: 999_999_999,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 365,
      support_level: :dedicated
    }
  end
end
