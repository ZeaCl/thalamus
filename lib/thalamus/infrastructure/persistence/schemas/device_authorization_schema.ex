defmodule Thalamus.Infrastructure.Persistence.Schemas.DeviceAuthorizationSchema do
  @moduledoc """
  Ecto schema for OAuth2 Device Authorization persistence.

  Stores pending device flow authorizations.
  Part of the Infrastructure layer — only used by repositories.

  SOLID Principles Applied:
  - Single Responsibility: Only handles database mapping for device authorizations
  - Dependency Inversion: Domain doesn't depend on this schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OAuth2ClientSchema}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "device_authorizations" do
    field :device_code, :string
    field :user_code, :string
    field :scopes, {:array, :string}, default: []
    field :status, :string, default: "pending"
    field :expires_at, :utc_datetime
    field :last_polled_at, :utc_datetime
    field :interval, :integer, default: 5
    field :authorized_at, :utc_datetime

    belongs_to :user, UserSchema
    belongs_to :client, OAuth2ClientSchema, foreign_key: :client_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @valid_statuses ["pending", "authorized", "expired"]

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :id,
      :device_code,
      :user_code,
      :client_id,
      :scopes,
      :status,
      :expires_at,
      :interval,
      :inserted_at
    ])
    |> validate_required([:device_code, :user_code, :client_id, :expires_at])
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:device_code)
    |> unique_constraint(:user_code)
    |> foreign_key_constraint(:client_id)
  end

  def authorize_changeset(device_auth, user_id) do
    device_auth
    |> change(%{
      status: "authorized",
      user_id: user_id,
      authorized_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  def poll_changeset(device_auth) do
    device_auth
    |> change(%{
      last_polled_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  def expire_changeset(device_auth) do
    device_auth
    |> change(%{
      status: "expired"
    })
  end
end
