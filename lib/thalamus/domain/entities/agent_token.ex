defmodule Thalamus.Domain.Entities.AgentToken do
  @moduledoc """
  Entity representing an agent authentication token.

  Agent tokens grant AI agents permission to act on behalf of users
  for specific, time-limited tasks.

  SOLID Principles Applied:
  - Single Responsibility: Only manages agent token lifecycle and validation
  - Open/Closed: Behavior can be extended without modifying core entity
  - Liskov Substitution: All AgentToken instances behave consistently
  """

  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  @type status :: :active | :revoked

  @type t :: %__MODULE__{
          id: String.t(),
          client_id: String.t(),
          organization_id: String.t(),
          agent_type: AgentType.t(),
          task_id: TaskId.t(),
          task_description: String.t(),
          scopes: [String.t()],
          delegation_chain: DelegationChain.t(),
          delegator_user_id: String.t(),
          expires_in: non_neg_integer(),
          status: status(),
          revoked_at: DateTime.t() | nil,
          revoke_reason: String.t() | nil,
          reason: String.t() | nil,
          created_at: DateTime.t()
        }

  defstruct [
    :id,
    :client_id,
    :organization_id,
    :agent_type,
    :task_id,
    :task_description,
    :scopes,
    :delegation_chain,
    :delegator_user_id,
    :expires_in,
    :status,
    :revoked_at,
    :revoke_reason,
    :reason,
    :created_at
  ]

  @doc """
  Creates a new AgentToken entity.

  ## Required Parameters

  - `client_id` - OAuth2 client identifier
  - `organization_id` - Multi-tenant organization identifier
  - `agent_type` - Type of agent (AgentType value object)
  - `task_id` - Unique task identifier (TaskId value object)
  - `task_description` - Human-readable task description
  - `scopes` - List of granted permissions
  - `delegation_chain` - Token delegation hierarchy (DelegationChain value object)
  - `delegator_user_id` - User who authorized the token
  - `expires_in` - Token lifetime in seconds

  ## Optional Parameters

  - `reason` - Optional reason for token creation

  ## Examples

      iex> {:ok, agent_type} = AgentType.new(:autonomous)
      iex> {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      iex> {:ok, chain} = DelegationChain.from_delegator("user-1")
      iex> params = %{
      ...>   client_id: "client-1",
      ...>   organization_id: "org-1",
      ...>   agent_type: agent_type,
      ...>   task_id: task_id,
      ...>   task_description: "Process data",
      ...>   scopes: ["read:data"],
      ...>   delegation_chain: chain,
      ...>   delegator_user_id: "user-1",
      ...>   expires_in: 3600
      ...> }
      iex> {:ok, token} = AgentToken.create(params)
      iex> token.status
      :active
  """
  @spec create(map()) :: {:ok, t()} | {:error, atom()}
  def create(params) when is_map(params) do
    with :ok <- validate_params(params),
         :ok <- validate_value_objects(params) do
      token = %__MODULE__{
        id: generate_id(),
        client_id: params.client_id,
        organization_id: params.organization_id,
        agent_type: params.agent_type,
        task_id: params.task_id,
        task_description: params.task_description,
        scopes: params.scopes,
        delegation_chain: params.delegation_chain,
        delegator_user_id: params.delegator_user_id,
        expires_in: params.expires_in,
        status: :active,
        revoked_at: nil,
        revoke_reason: nil,
        reason: Map.get(params, :reason),
        created_at: DateTime.utc_now()
      }

      {:ok, token}
    end
  end

  def create(_), do: {:error, :invalid_agent_token}

  @doc """
  Revokes an agent token.

  Once revoked, the token can no longer be used for authentication.
  Revocation is permanent and cannot be undone.

  ## Parameters

  - `token` - The AgentToken to revoke
  - `reason` - Optional reason for revocation

  ## Examples

      iex> {:ok, token} = AgentToken.create(valid_params)
      iex> {:ok, revoked} = AgentToken.revoke(token, "Task completed")
      iex> revoked.status
      :revoked
  """
  @spec revoke(t(), String.t() | nil) :: {:ok, t()} | {:error, atom()}
  def revoke(%__MODULE__{status: :revoked}, _reason) do
    {:error, :already_revoked}
  end

  def revoke(%__MODULE__{} = token, reason) do
    revoked_token = %{
      token
      | status: :revoked,
        revoked_at: DateTime.utc_now(),
        revoke_reason: reason
    }

    {:ok, revoked_token}
  end

  @doc """
  Checks if the token is active (not revoked and not expired).

  ## Examples

      iex> {:ok, token} = AgentToken.create(valid_params)
      iex> AgentToken.active?(token)
      true

      iex> {:ok, revoked} = AgentToken.revoke(token, "Revoked")
      iex> AgentToken.active?(revoked)
      false
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: :revoked}), do: false
  def active?(%__MODULE__{} = token), do: not expired?(token)

  @doc """
  Checks if the token has expired based on created_at and expires_in.

  ## Examples

      iex> {:ok, token} = AgentToken.create(Map.put(valid_params, :expires_in, 3600))
      iex> AgentToken.expired?(token)
      false

      iex> {:ok, expired_token} = AgentToken.create(Map.put(valid_params, :expires_in, -100))
      iex> AgentToken.expired?(expired_token)
      true
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{} = token) do
    expires_at = expires_at(token)
    now = DateTime.utc_now()
    DateTime.compare(now, expires_at) in [:gt, :eq]
  end

  @doc """
  Checks if the token has been revoked.

  ## Examples

      iex> {:ok, token} = AgentToken.create(valid_params)
      iex> AgentToken.revoked?(token)
      false

      iex> {:ok, revoked} = AgentToken.revoke(token, "Done")
      iex> AgentToken.revoked?(revoked)
      true
  """
  @spec revoked?(t()) :: boolean()
  def revoked?(%__MODULE__{status: :revoked}), do: true
  def revoked?(%__MODULE__{}), do: false

  @doc """
  Calculates the absolute expiration time of the token.

  ## Examples

      iex> {:ok, token} = AgentToken.create(Map.put(valid_params, :expires_in, 3600))
      iex> expires_at = AgentToken.expires_at(token)
      iex> DateTime.diff(expires_at, token.created_at)
      3600
  """
  @spec expires_at(t()) :: DateTime.t()
  def expires_at(%__MODULE__{created_at: created_at, expires_in: expires_in}) do
    DateTime.add(created_at, expires_in, :second)
  end

  @doc """
  Calculates seconds until expiration.

  Returns positive number if token is still valid, negative if expired.

  ## Examples

      iex> {:ok, token} = AgentToken.create(Map.put(valid_params, :expires_in, 3600))
      iex> seconds = AgentToken.time_until_expiration(token)
      iex> seconds > 0 and seconds <= 3600
      true
  """
  @spec time_until_expiration(t()) :: integer()
  def time_until_expiration(%__MODULE__{} = token) do
    expires_at = expires_at(token)
    now = DateTime.utc_now()
    DateTime.diff(expires_at, now)
  end

  # Private helper functions

  defp generate_id do
    Ecto.UUID.generate()
  end

  defp validate_params(params) do
    required_keys = [
      :client_id,
      :organization_id,
      :agent_type,
      :task_id,
      :task_description,
      :scopes,
      :delegation_chain,
      :delegator_user_id,
      :expires_in
    ]

    missing_keys = required_keys -- Map.keys(params)

    cond do
      length(missing_keys) > 0 ->
        {:error, :invalid_agent_token}

      not is_binary(params.client_id) or params.client_id == "" ->
        {:error, :invalid_agent_token}

      not is_binary(params.organization_id) or params.organization_id == "" ->
        {:error, :invalid_agent_token}

      not is_binary(params.task_description) ->
        {:error, :invalid_agent_token}

      not is_list(params.scopes) ->
        {:error, :invalid_agent_token}

      not is_binary(params.delegator_user_id) or params.delegator_user_id == "" ->
        {:error, :invalid_agent_token}

      not is_integer(params.expires_in) ->
        {:error, :invalid_agent_token}

      true ->
        :ok
    end
  end

  defp validate_value_objects(params) do
    cond do
      not is_struct(params.agent_type, AgentType) ->
        {:error, :invalid_agent_token}

      not is_struct(params.task_id, TaskId) ->
        {:error, :invalid_agent_token}

      not is_struct(params.delegation_chain, DelegationChain) ->
        {:error, :invalid_agent_token}

      true ->
        :ok
    end
  end
end
