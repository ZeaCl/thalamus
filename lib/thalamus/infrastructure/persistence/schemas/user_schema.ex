defmodule Thalamus.Infrastructure.Persistence.Schemas.UserSchema do
  @moduledoc """
  Ecto schema for User persistence.

  Maps the User domain entity to the database.
  This is part of the Infrastructure layer and should only be used by repositories.

  SOLID Principles Applied:
  - Single Responsibility: Only handles database mapping
  - Dependency Inversion: Domain entities don't depend on this schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :name, :string
    field :password_hash, :string
    field :status, Ecto.Enum, values: [:pending_verification, :active, :suspended, :deactivated]
    field :verified_at, :utc_datetime
    field :last_login_at, :utc_datetime
    field :failed_login_attempts, :integer, default: 0
    field :locked_until, :utc_datetime

    # MFA methods stored as JSONB array
    field :mfa_methods, {:array, :map}, default: []

    field :is_agent, :boolean, default: false
    field :agent_config, :map, default: %{}

    # Relationships
    belongs_to :organization, OrganizationSchema

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new user.

  ## Required fields
  - email
  - password_hash
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :email,
      :name,
      :password_hash,
      :organization_id,
      :status,
      :verified_at,
      :last_login_at,
      :failed_login_attempts,
      :locked_until,
      :mfa_methods,
      :is_agent,
      :agent_config
    ])
    |> validate_required([:email, :password_hash])
    |> validate_email()
    |> put_default_values_if_missing()
    |> unique_constraint(:email)
  end

  @doc """
  Changeset for updating user attributes.
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :name,
      :password_hash,
      :status,
      :verified_at,
      :last_login_at,
      :failed_login_attempts,
      :locked_until,
      :mfa_methods,
      :organization_id,
      :is_agent,
      :agent_config
    ])
    |> validate_email()
    |> unique_constraint(:email)
  end

  @doc """
  Changeset for email verification.
  """
  def verify_email_changeset(user) do
    user
    |> change(%{
      status: :active,
      verified_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  @doc """
  Changeset for recording a successful login.
  """
  def successful_login_changeset(user) do
    user
    |> change(%{
      last_login_at: DateTime.truncate(DateTime.utc_now(), :second),
      failed_login_attempts: 0,
      locked_until: nil
    })
  end

  @doc """
  Changeset for recording a failed login attempt.
  """
  def failed_login_changeset(user, failed_attempts) do
    changes = %{failed_login_attempts: failed_attempts}

    # Lock account after 5 failed attempts
    changes =
      if failed_attempts >= 5 do
        Map.put(
          changes,
          :locked_until,
          DateTime.add(DateTime.truncate(DateTime.utc_now(), :second), 1800, :second)
        )
      else
        changes
      end

    change(user, changes)
  end

  @doc """
  Changeset for changing password.
  """
  def password_changeset(user, new_password_hash) do
    user
    |> change(%{password_hash: new_password_hash})
    |> validate_required([:password_hash])
  end

  @doc """
  Changeset for adding an MFA method.
  """
  def add_mfa_method_changeset(user, mfa_method_map) do
    existing_methods = user.mfa_methods || []
    new_methods = existing_methods ++ [mfa_method_map]

    user
    |> change(%{mfa_methods: new_methods})
  end

  @doc """
  Changeset for removing an MFA method.
  """
  def remove_mfa_method_changeset(user, mfa_method_map) do
    existing_methods = user.mfa_methods || []

    new_methods =
      Enum.reject(existing_methods, fn method ->
        method["type"] == mfa_method_map["type"] &&
          method["identifier"] == mfa_method_map["identifier"]
      end)

    user
    |> change(%{mfa_methods: new_methods})
  end

  @doc """
  Changeset for suspending a user account.
  """
  def suspend_changeset(user) do
    user
    |> change(%{status: :suspended})
  end

  @doc """
  Changeset for reactivating a user account.
  """
  def reactivate_changeset(user) do
    user
    |> change(%{status: :active})
  end

  @doc """
  Changeset for deactivating a user account permanently.
  """
  def deactivate_changeset(user) do
    user
    |> change(%{status: :deactivated})
  end

  # Private functions

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> validate_length(:email, max: 254)
    |> update_change(:email, &String.downcase/1)
  end

  defp put_default_values_if_missing(changeset) do
    changeset
    |> put_default_if_missing(:status, :pending_verification)
    |> put_default_if_missing(:failed_login_attempts, 0)
    |> put_default_if_missing(:is_agent, false)
    |> put_default_if_missing(:agent_config, %{})
  end

  defp put_default_if_missing(changeset, field, default_value) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, default_value)
      _ -> changeset
    end
  end
end
