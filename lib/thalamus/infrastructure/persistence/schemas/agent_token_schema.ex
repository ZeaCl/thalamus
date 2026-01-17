defmodule Thalamus.Infrastructure.Persistence.Schemas.AgentTokenSchema do
  @moduledoc """
  Ecto schema for agent_tokens table.

  Maps database records to Elixir structs for persistence operations.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    OAuth2ClientSchema,
    OrganizationSchema
  }

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agent_tokens" do
    # OAuth2 and multi-tenancy
    belongs_to :client, OAuth2ClientSchema, foreign_key: :client_id
    belongs_to :organization, OrganizationSchema, foreign_key: :organization_id

    # Token data
    field :access_token, :string

    # Agent metadata
    field :agent_type, :string
    field :task_id, :binary_id
    field :task_description, :string
    field :scopes, {:array, :string}, default: []

    # Delegation tracking
    belongs_to :parent_agent, __MODULE__, foreign_key: :parent_agent_id
    has_many :child_agents, __MODULE__, foreign_key: :parent_agent_id

    field :delegation_chain, :map, default: %{}
    field :delegation_depth, :integer, default: 0
    field :delegator_user_id, :binary_id

    # Token lifecycle
    field :expires_in, :integer
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :revoke_reason, :string
    field :reason, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new agent token.

  ## Required fields
  - client_id
  - organization_id
  - access_token
  - agent_type
  - task_id
  - task_description
  - scopes
  - delegation_chain
  - delegation_depth
  - delegator_user_id
  - expires_in
  - expires_at

  ## Optional fields
  - parent_agent_id
  - reason
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [
      :client_id,
      :organization_id,
      :access_token,
      :agent_type,
      :task_id,
      :task_description,
      :scopes,
      :parent_agent_id,
      :delegation_chain,
      :delegation_depth,
      :delegator_user_id,
      :expires_in,
      :expires_at,
      :reason
    ])
    |> validate_required([
      :client_id,
      :organization_id,
      :access_token,
      :agent_type,
      :task_id,
      :task_description,
      :scopes,
      :delegation_chain,
      :delegation_depth,
      :delegator_user_id,
      :expires_in,
      :expires_at
    ])
    |> validate_inclusion(:agent_type, ["autonomous", "supervisor", "tool"])
    |> validate_number(:delegation_depth, greater_than_or_equal_to: 0, less_than: 5)
    |> validate_length(:access_token, min: 10, max: 255)
    |> validate_length(:task_description, min: 1)
    |> validate_number(:expires_in, greater_than: 0)
    |> unique_constraint(:access_token, name: :idx_agent_tokens_access_token)
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:parent_agent_id)
    |> check_constraint(:agent_type, name: :valid_agent_type)
    |> check_constraint(:delegation_depth, name: :valid_delegation_depth)
  end

  @doc """
  Changeset for updating an agent token (typically for revocation).

  Only allows updating revocation-related fields.
  """
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:revoked_at, :revoke_reason])
    |> validate_required([:revoked_at])
  end
end
