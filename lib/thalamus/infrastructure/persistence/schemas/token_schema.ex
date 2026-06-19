defmodule Thalamus.Infrastructure.Persistence.Schemas.TokenSchema do
  @moduledoc """
  Ecto schema for OAuth2 Token persistence.

  Stores access tokens, refresh tokens, and authorization codes.
  This is part of the Infrastructure layer and should only be used by repositories.

  SOLID Principles Applied:
  - Single Responsibility: Only handles database mapping for tokens
  - Dependency Inversion: Domain doesn't depend on this schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OAuth2ClientSchema}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tokens" do
    field :token, :string
    field :type, Ecto.Enum, values: [:access_token, :refresh_token, :authorization_code]
    field :scopes, {:array, :string}, default: []
    field :expires_at, :utc_datetime
    field :revoked, :boolean, default: false
    field :revoked_at, :utc_datetime

    # PKCE support
    field :code_challenge, :string
    field :code_challenge_method, :string

    # Token family for refresh token rotation
    field :token_family_id, :binary_id

    # Flexible metadata for custom claims
    field :metadata, :map, default: %{}

    # Agent Identity
    field :agent_type, :string
    field :delegated_by_user_id, :binary_id
    field :delegation_chain, {:array, :binary_id}, default: []

    # Task Scoping
    field :task_id, :string
    field :task_type, :string
    field :task_scopes, {:array, :string}, default: []
    field :max_operations, :integer
    field :operations_count, :integer, default: 0
    field :expires_on_completion, :boolean, default: false

    # Attestation (Compliance)
    field :intent_description, :string
    field :orchestrator_id, :string
    field :environment, :string

    # Relationships
    belongs_to :user, UserSchema
    belongs_to :client, OAuth2ClientSchema, foreign_key: :client_id
    belongs_to :organization, Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating a new token.

  ## Required fields
  - token
  - type
  - client_id
  - expires_at
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :id,
      :token,
      :type,
      :user_id,
      :client_id,
      :organization_id,
      :scopes,
      :expires_at,
      :revoked,
      :revoked_at,
      :code_challenge,
      :code_challenge_method,
      :token_family_id,
      :metadata,
      # Agent fields
      :agent_type,
      :delegated_by_user_id,
      :delegation_chain,
      :task_id,
      :task_type,
      :task_scopes,
      :max_operations,
      :operations_count,
      :expires_on_completion,
      :intent_description,
      :orchestrator_id,
      :environment,
      :inserted_at
    ])
    |> validate_required([:token, :type, :client_id, :expires_at])
    |> validate_token_type()
    |> validate_expiration()
    |> put_default_values()
    |> unique_constraint(:token)
  end

  @doc """
  Changeset for revoking a token.
  """
  def revoke_changeset(token) do
    token
    |> change(%{
      revoked: true,
      revoked_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  @doc """
  Changeset for creating an access token.
  """
  def access_token_changeset(attrs) do
    attrs
    |> Map.put(:type, :access_token)
    |> create_changeset()
  end

  @doc """
  Changeset for creating a refresh token.
  """
  def refresh_token_changeset(attrs) do
    attrs
    |> Map.put(:type, :refresh_token)
    |> create_changeset()
  end

  @doc """
  Changeset for creating an authorization code.
  """
  def authorization_code_changeset(attrs) do
    attrs
    |> Map.put(:type, :authorization_code)
    |> create_changeset()
    |> validate_pkce()
  end

  # Private functions

  defp validate_token_type(changeset) do
    changeset
    |> validate_required([:type])
    |> validate_inclusion(:type, [:access_token, :refresh_token, :authorization_code])
  end

  defp validate_expiration(changeset) do
    case get_change(changeset, :expires_at) do
      nil ->
        add_error(changeset, :expires_at, "can't be blank")

      expires_at ->
        # Skip future validation if:
        # 1. Token has explicit inserted_at (test data or migration)
        # 2. Token is already revoked (historical data)
        has_explicit_timestamp = get_change(changeset, :inserted_at) != nil
        is_revoked = get_change(changeset, :revoked) == true

        if has_explicit_timestamp or is_revoked do
          changeset
        else
          now = DateTime.utc_now()

          if DateTime.compare(expires_at, now) == :gt do
            changeset
          else
            add_error(changeset, :expires_at, "must be in the future")
          end
        end
    end
  end

  defp validate_pkce(changeset) do
    code_challenge = get_change(changeset, :code_challenge)
    code_challenge_method = get_change(changeset, :code_challenge_method)

    cond do
      # Both present - valid
      code_challenge && code_challenge_method ->
        changeset
        |> validate_inclusion(:code_challenge_method, ["S256", "plain"])

      # Only one present - invalid
      code_challenge || code_challenge_method ->
        add_error(
          changeset,
          :code_challenge,
          "both code_challenge and code_challenge_method must be present"
        )

      # Both absent - valid (PKCE optional for some flows)
      true ->
        changeset
    end
  end

  defp put_default_values(changeset) do
    changeset
    |> put_change(:revoked, false)
  end
end
