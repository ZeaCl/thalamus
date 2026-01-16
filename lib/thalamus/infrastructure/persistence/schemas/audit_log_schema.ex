defmodule Thalamus.Infrastructure.Persistence.Schemas.AuditLogSchema do
  @moduledoc """
  Ecto schema for Audit Log persistence.

  Stores immutable audit records for security and compliance purposes.
  This is part of the Infrastructure layer and should only be used by repositories.

  SOLID Principles Applied:
  - Single Responsibility: Only handles database mapping for audit logs
  - Dependency Inversion: Domain doesn't depend on this schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    UserSchema,
    OrganizationSchema,
    OAuth2ClientSchema
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @event_types [
    "authentication_success",
    "authentication_failure",
    "token_generated",
    "token_revoked",
    "mfa_enabled",
    "mfa_disabled",
    "mfa_setup_initiated",
    "mfa_verification_success",
    "mfa_verification_failed",
    "password_changed",
    "organization_created",
    "organization_event",
    "member_added",
    "member_removed",
    "client_created",
    "client_event",
    "client_secret_rotated",
    "backup_codes_regenerated",
    "failed_login",
    "user_created",
    "user_updated",
    "user_deleted",
    "organization_updated",
    "organization_deleted"
  ]

  schema "audit_logs" do
    field :event_type, :string
    field :metadata, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string
    field :request_id, :string
    field :environment, :string
    field :node, :string

    # Relationships
    belongs_to :user, UserSchema
    belongs_to :organization, OrganizationSchema
    belongs_to :client, OAuth2ClientSchema

    # Timestamps (only inserted_at, no updates for immutability)
    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating a new audit log entry.

  Audit logs are immutable - once created, they cannot be modified.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :event_type,
      :user_id,
      :organization_id,
      :client_id,
      :metadata,
      :ip_address,
      :user_agent,
      :request_id,
      :environment,
      :node
    ])
    |> validate_required([:event_type])
    |> validate_inclusion(:event_type, @event_types)
    |> put_timestamp()
  end

  defp put_timestamp(changeset) do
    put_change(changeset, :inserted_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Returns the list of valid event types.
  """
  def event_types, do: @event_types
end
