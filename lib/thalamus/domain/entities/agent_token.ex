defmodule Thalamus.Domain.Entities.AgentToken do
  @moduledoc """
  Domain entity representing an agent-specific OAuth2 access token.

  SOLID Principles Applied:
  - Single Responsibility: Only manages agent token state and business rules
  - Open/Closed: Extensible via delegation chain without modifying core logic
  - Liskov Substitution: Can be used wherever a token entity is expected

  Per 03-tasks.md Epic 1.2 specification.
  """

  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          access_token: String.t(),
          agent_type: AgentType.t(),
          task_id: TaskId.t() | nil,
          delegation_chain: DelegationChain.t(),
          scopes: [String.t()],
          reason: String.t() | nil,
          expires_at: DateTime.t(),
          revoked_at: DateTime.t() | nil,
          organization_id: Ecto.UUID.t(),
          client_id: Ecto.UUID.t(),
          created_at: DateTime.t()
        }

  defstruct [
    :id,
    :access_token,
    :agent_type,
    :task_id,
    :delegation_chain,
    :scopes,
    :reason,
    :expires_at,
    :revoked_at,
    :organization_id,
    :client_id,
    :created_at
  ]

  @doc """
  Creates a new AgentToken entity.

  ## Parameters

  - `attrs` - Map with keys:
    - `:access_token` - Cryptographically secure token string (required)
    - `:agent_type` - AgentType value object (required)
    - `:organization_id` - UUID of the organization (required)
    - `:client_id` - UUID of the OAuth2 client (required)
    - `:scopes` - List of scope strings (required)
    - `:task_id` - TaskId value object (optional)
    - `:delegation_chain` - DelegationChain value object (optional, defaults to root)
    - `:reason` - Human-readable justification (optional)
    - `:expires_at` - Expiration timestamp (required)

  ## Returns

  - `{:ok, %AgentToken{}}` - Valid token entity
  - `{:error, reason}` - Validation failure

  ## Examples

      iex> {:ok, agent_type} = AgentType.new("autonomous")
      iex> {:ok, chain} = DelegationChain.root()
      iex> AgentToken.create(%{
      ...>   access_token: "at_abc123",
      ...>   agent_type: agent_type,
      ...>   organization_id: org_id,
      ...>   client_id: client_id,
      ...>   scopes: ["read:data"],
      ...>   delegation_chain: chain,
      ...>   expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      ...> })
      {:ok, %AgentToken{}}
  """
  @spec create(map()) :: {:ok, t()} | {:error, atom()}
  def create(attrs) do
    with :ok <- validate_required_fields(attrs),
         :ok <- validate_agent_type(attrs[:agent_type]),
         :ok <- validate_scopes(attrs[:scopes]),
         :ok <- validate_uuids(attrs),
         :ok <- validate_expiration(attrs[:expires_at]) do
      # Get or create default delegation chain
      default_chain =
        case DelegationChain.root() do
          {:ok, chain} -> chain
          _ -> %DelegationChain{chain: []}
        end

      token = %__MODULE__{
        id: Map.get(attrs, :id, Ecto.UUID.generate()),
        access_token: attrs[:access_token],
        agent_type: attrs[:agent_type],
        task_id: Map.get(attrs, :task_id),
        delegation_chain: Map.get(attrs, :delegation_chain, default_chain),
        scopes: attrs[:scopes],
        reason: Map.get(attrs, :reason),
        expires_at: attrs[:expires_at],
        revoked_at: nil,
        organization_id: attrs[:organization_id],
        client_id: attrs[:client_id],
        created_at: Map.get(attrs, :created_at, DateTime.utc_now())
      }

      {:ok, token}
    end
  end

  @doc """
  Revokes an agent token with a timestamp.

  ## Examples

      iex> AgentToken.revoke(token)
      {:ok, %AgentToken{revoked_at: ~U[2026-01-18 00:00:00Z]}}
  """
  @spec revoke(t()) :: {:ok, t()}
  def revoke(%__MODULE__{} = token) do
    revoked_token = %{token | revoked_at: DateTime.utc_now()}
    {:ok, revoked_token}
  end

  @doc """
  Checks if the token is active (not revoked and not expired).

  ## Examples

      iex> AgentToken.active?(token)
      true
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{} = token) do
    not revoked?(token) and not expired?(token)
  end

  @doc """
  Checks if the token has expired.

  ## Examples

      iex> AgentToken.expired?(token)
      false
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if the token has been revoked.

  ## Examples

      iex> AgentToken.revoked?(token)
      false
  """
  @spec revoked?(t()) :: boolean()
  def revoked?(%__MODULE__{revoked_at: nil}), do: false
  def revoked?(%__MODULE__{revoked_at: _}), do: true

  # Private validation functions

  defp validate_required_fields(attrs) do
    required = [:access_token, :agent_type, :organization_id, :client_id, :scopes, :expires_at]

    missing = Enum.filter(required, fn field -> is_nil(Map.get(attrs, field)) end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_agent_type(%AgentType{}), do: :ok
  defp validate_agent_type(_), do: {:error, :invalid_agent_type}

  defp validate_scopes(scopes) when is_list(scopes) and length(scopes) > 0, do: :ok
  defp validate_scopes([]), do: {:error, :empty_scopes}
  defp validate_scopes(_), do: {:error, :invalid_scopes}

  defp validate_uuids(attrs) do
    with :ok <- validate_uuid(attrs[:organization_id], :invalid_organization_id),
         :ok <- validate_uuid(attrs[:client_id], :invalid_client_id) do
      :ok
    end
  end

  defp validate_uuid(value, error) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, _} -> :ok
      :error -> {:error, error}
    end
  end

  defp validate_uuid(_, error), do: {:error, error}

  defp validate_expiration(%DateTime{} = expires_at) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
      :ok
    else
      {:error, :expiration_in_past}
    end
  end

  defp validate_expiration(_), do: {:error, :invalid_expiration}
end
