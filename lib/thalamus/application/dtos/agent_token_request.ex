defmodule Thalamus.Application.DTOs.AgentTokenRequest do
  @moduledoc """
  Data Transfer Object for agent token generation requests.

  This DTO bridges the presentation layer (HTTP params) and application layer (use case).

  SOLID Principles:
  - Single Responsibility: Only validates and structures agent token requests
  - Open/Closed: Extensible validation without modifying core logic
  """

  alias Thalamus.Domain.ValueObjects.AgentType

  @type t :: %__MODULE__{
          # OAuth2 Standard Fields (for M2M authentication)
          client_id: String.t(),
          client_secret: String.t(),
          organization_id: String.t(),

          # Agent-Specific Fields (REQUIRED)
          # Human who authorized the agent
          delegator_user_id: String.t(),
          # "autonomous" | "supervisor" | "tool"
          agent_type: String.t(),

          # Task-Scoping Fields (REQUIRED)
          # External task identifier (UUID)
          task_id: String.t() | nil,
          # Human-readable task description
          task_description: String.t(),
          # Subset of client.allowed_scopes
          scopes: [String.t()],

          # Delegation Fields (OPTIONAL - for child agents)
          # Parent agent token ID
          parent_agent_id: String.t() | nil,

          # Token Configuration (OPTIONAL)
          # Custom TTL in seconds (default 3600, max 3600)
          expires_in: non_neg_integer() | nil,

          # Attestation Fields (OPTIONAL)
          # Human-readable reason/intent
          reason: String.t() | nil
        }

  defstruct [
    :client_id,
    :client_secret,
    :organization_id,
    :delegator_user_id,
    :agent_type,
    :task_id,
    :task_description,
    :parent_agent_id,
    :expires_in,
    :reason,
    scopes: []
  ]

  @max_ttl 3600
  @default_ttl 3600

  @doc """
  Validates the request structure and field constraints.

  ## Validation Rules

  - client_id: Required, non-empty
  - client_secret: Required for confidential clients
  - organization_id: Required, valid UUID
  - delegator_user_id: Required, valid UUID
  - agent_type: Required, must be valid AgentType (autonomous, supervisor, tool)
  - task_description: Required, non-empty
  - scopes: Required, non-empty array
  - expires_in: Optional, max 3600 seconds (1 hour) for agent tokens
  - parent_agent_id: Optional, must be valid UUID if provided
  """
  @spec validate(t()) :: :ok | {:error, atom()}
  def validate(%__MODULE__{} = request) do
    with :ok <- validate_client_credentials(request),
         :ok <- validate_organization(request),
         :ok <- validate_delegator(request),
         :ok <- validate_agent_type(request),
         :ok <- validate_task_description(request),
         :ok <- validate_scopes(request),
         :ok <- validate_expires_in(request),
         :ok <- validate_parent_agent_id(request) do
      :ok
    end
  end

  defp validate_client_credentials(%{client_id: nil}), do: {:error, :missing_client_id}
  defp validate_client_credentials(%{client_id: ""}), do: {:error, :missing_client_id}
  defp validate_client_credentials(%{client_secret: nil}), do: {:error, :missing_client_secret}
  defp validate_client_credentials(%{client_secret: ""}), do: {:error, :missing_client_secret}
  defp validate_client_credentials(_), do: :ok

  defp validate_organization(%{organization_id: nil}), do: {:error, :missing_organization_id}
  defp validate_organization(%{organization_id: ""}), do: {:error, :missing_organization_id}

  defp validate_organization(%{organization_id: org_id}) do
    case Ecto.UUID.cast(org_id) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_organization_id}
    end
  end

  defp validate_delegator(%{delegator_user_id: nil}),
    do: {:error, :missing_delegator_user_id}

  defp validate_delegator(%{delegator_user_id: ""}),
    do: {:error, :missing_delegator_user_id}

  defp validate_delegator(%{delegator_user_id: user_id}) do
    case Ecto.UUID.cast(user_id) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_delegator_user_id}
    end
  end

  defp validate_agent_type(%{agent_type: nil}), do: {:error, :missing_agent_type}

  defp validate_agent_type(%{agent_type: type}) do
    case AgentType.new(type) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :invalid_agent_type}
    end
  end

  defp validate_task_description(%{task_description: nil}),
    do: {:error, :missing_task_description}

  defp validate_task_description(%{task_description: ""}),
    do: {:error, :empty_task_description}

  defp validate_task_description(%{task_description: desc}) when is_binary(desc), do: :ok
  defp validate_task_description(_), do: {:error, :invalid_task_description}

  defp validate_scopes(%{scopes: []}), do: {:error, :empty_scopes}
  defp validate_scopes(%{scopes: scopes}) when is_list(scopes), do: :ok
  defp validate_scopes(_), do: {:error, :invalid_scopes}

  defp validate_expires_in(%{expires_in: nil}), do: :ok

  defp validate_expires_in(%{expires_in: ttl})
       when is_integer(ttl) and ttl > 0 and ttl <= @max_ttl,
       do: :ok

  defp validate_expires_in(%{expires_in: ttl}) when is_integer(ttl) and ttl > @max_ttl,
    do: {:error, :ttl_exceeds_maximum}

  defp validate_expires_in(_), do: {:error, :invalid_expires_in}

  defp validate_parent_agent_id(%{parent_agent_id: nil}), do: :ok
  defp validate_parent_agent_id(%{parent_agent_id: ""}), do: {:error, :invalid_parent_agent_id}

  defp validate_parent_agent_id(%{parent_agent_id: parent_id}) do
    case Ecto.UUID.cast(parent_id) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_parent_agent_id}
    end
  end

  @doc """
  Returns default TTL if not specified in request.
  """
  @spec get_expires_in(t()) :: non_neg_integer()
  def get_expires_in(%__MODULE__{expires_in: nil}), do: @default_ttl
  def get_expires_in(%__MODULE__{expires_in: ttl}), do: ttl
end
