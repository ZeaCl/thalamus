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
          id: String.t() | nil,
          access_token: String.t(),
          agent_type: AgentType.t(),
          task_id: TaskId.t() | nil,
          delegation_chain: DelegationChain.t(),
          scopes: [String.t()],
          reason: String.t() | nil,
          expires_at: DateTime.t(),
          revoked_at: DateTime.t() | nil,
          organization_id: String.t(),
          client_id: String.t(),
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
         :ok <- validate_access_token(attrs[:access_token]),
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
        id: Map.get(attrs, :id, generate_uuid()),
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

  ## Parameters

  - `token` - AgentToken to revoke
  - `revoked_at` - Optional timestamp (defaults to current time)

  ## Examples

      iex> AgentToken.revoke(token)
      {:ok, %AgentToken{revoked_at: ~U[2026-01-18 00:00:00Z]}}
  """
  @spec revoke(t(), DateTime.t()) :: {:ok, t()}
  def revoke(%__MODULE__{} = token, revoked_at \\ DateTime.utc_now()) do
    revoked_token = %{token | revoked_at: revoked_at}
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

  ## Parameters

  - `token` - AgentToken to check
  - `now` - Optional current time (defaults to DateTime.utc_now())

  ## Examples

      iex> AgentToken.expired?(token)
      false
  """
  @spec expired?(t(), DateTime.t()) :: boolean()
  def expired?(%__MODULE__{expires_at: expires_at}, now \\ DateTime.utc_now()) do
    DateTime.compare(now, expires_at) == :gt
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

  @doc """
  Creates an AgentToken from trusted attributes without validation.

  This function should ONLY be used when reconstructing tokens from trusted sources
  like the database, where data has already been validated on insertion.

  Using this for untrusted input bypasses critical security validations.

  ## Parameters

  - `attrs` - Map with all required fields (no validation performed)

  ## Returns

  - `{:ok, %AgentToken{}}` - Token entity

  ## Examples

      iex> AgentToken.from_trusted_attrs(%{
      ...>   id: "123e4567-e89b-12d3-a456-426614174000",
      ...>   access_token: "at_trusted_token_from_db",
      ...>   # ... other required fields from database
      ...> })
      {:ok, %AgentToken{}}
  """
  @spec from_trusted_attrs(map()) :: {:ok, t()}
  def from_trusted_attrs(attrs) do
    # Get or create default delegation chain if not provided
    default_chain =
      case DelegationChain.root() do
        {:ok, chain} -> chain
        _ -> %DelegationChain{chain: []}
      end

    token = %__MODULE__{
      id: Map.get(attrs, :id),
      access_token: Map.fetch!(attrs, :access_token),
      agent_type: Map.fetch!(attrs, :agent_type),
      task_id: Map.get(attrs, :task_id),
      delegation_chain: Map.get(attrs, :delegation_chain, default_chain),
      scopes: Map.fetch!(attrs, :scopes),
      reason: Map.get(attrs, :reason),
      expires_at: Map.fetch!(attrs, :expires_at),
      revoked_at: Map.get(attrs, :revoked_at),
      organization_id: Map.fetch!(attrs, :organization_id),
      client_id: Map.fetch!(attrs, :client_id),
      created_at: Map.get(attrs, :created_at, DateTime.utc_now())
    }

    {:ok, token}
  end

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

  defp validate_access_token(token) when is_binary(token) and byte_size(token) >= 32 do
    :ok
  end

  defp validate_access_token(token) when is_binary(token) do
    {:error, :access_token_too_short}
  end

  defp validate_access_token(_), do: {:error, :invalid_access_token}

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
    if valid_uuid?(value) do
      :ok
    else
      {:error, error}
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

  # Pure UUID validation without Ecto dependency
  defp valid_uuid?(string) when is_binary(string) do
    # UUID format: 8-4-4-4-12 hex characters
    case String.split(string, "-") do
      [a, b, c, d, e] ->
        byte_size(a) == 8 and byte_size(b) == 4 and byte_size(c) == 4 and
          byte_size(d) == 4 and byte_size(e) == 12 and
          String.match?(
            string,
            ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
          )

      _ ->
        false
    end
  end

  defp valid_uuid?(_), do: false

  # Pure UUID v4 generation without Ecto dependency
  defp generate_uuid do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    # Set version (4) and variant (RFC 4122)
    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    |> uuid_to_string()
  end

  defp uuid_to_string(<<u0::32, u1::16, u2::16, u3::16, u4::48>>) do
    :io_lib.format(
      "~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
      [u0, u1, u2, u3, u4]
    )
    |> IO.iodata_to_binary()
    |> String.downcase()
  end
end
