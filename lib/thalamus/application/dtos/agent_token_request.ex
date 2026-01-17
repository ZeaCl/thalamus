defmodule Thalamus.Application.DTOs.AgentTokenRequest do
  @moduledoc """
  Data Transfer Object for agent token generation requests.

  This DTO bridges the presentation layer (HTTP params) and application layer (use case).
  """

  @type t :: %__MODULE__{
          # OAuth2 Standard Fields
          client_id: String.t(),
          client_secret: String.t(),

          # Agent-Specific Fields (REQUIRED)
          # Human who authorized the agent
          delegated_by_user_id: String.t(),
          # "autonomous" | "supervisor" | "tool"
          agent_type: String.t(),

          # Task-Scoping Fields (OPTIONAL)
          # External task identifier
          task_id: String.t() | nil,
          # Task classification
          task_type: String.t() | nil,
          # Subset of client.allowed_scopes
          task_scopes: [String.t()],
          # Operation limit
          max_operations: non_neg_integer() | nil,
          # Auto-revoke on task completion
          expires_on_completion: boolean(),

          # Attestation Fields (OPTIONAL)
          # Human-readable intent
          intent_description: String.t() | nil,
          # Orchestrator instance ID
          orchestrator_id: String.t() | nil,

          # Token Configuration (OPTIONAL)
          # Custom TTL in seconds (max 3600)
          ttl: non_neg_integer() | nil
        }

  defstruct [
    :client_id,
    :client_secret,
    :delegated_by_user_id,
    :agent_type,
    :task_id,
    :task_type,
    :max_operations,
    :intent_description,
    :orchestrator_id,
    :ttl,
    task_scopes: [],
    expires_on_completion: false
  ]

  @doc """
  Validates the request structure and field constraints.

  ## Validation Rules

  - client_id: Required, non-empty
  - client_secret: Required for confidential clients
  - delegated_by_user_id: Required, must be valid user UUID
  - agent_type: Required, must be valid AgentType
  - task_scopes: Must be subset of client.allowed_scopes (validated in use case)
  - ttl: Max 3600 seconds (1 hour) for agent tokens
  """
  @spec validate(t()) :: :ok | {:error, atom()}
  def validate(%__MODULE__{} = request) do
    with :ok <- validate_client_credentials(request),
         :ok <- validate_delegator(request),
         :ok <- validate_agent_type(request),
         :ok <- validate_task_scopes(request),
         :ok <- validate_ttl(request) do
      :ok
    end
  end

  defp validate_client_credentials(%{client_id: nil}), do: {:error, :missing_client_id}
  defp validate_client_credentials(%{client_id: ""}), do: {:error, :missing_client_id}
  defp validate_client_credentials(%{client_secret: nil}), do: {:error, :missing_client_secret}
  defp validate_client_credentials(%{client_secret: ""}), do: {:error, :missing_client_secret}
  defp validate_client_credentials(_), do: :ok

  defp validate_delegator(%{delegated_by_user_id: nil}),
    do: {:error, :missing_delegated_by_user_id}

  defp validate_delegator(%{delegated_by_user_id: ""}),
    do: {:error, :missing_delegated_by_user_id}

  defp validate_delegator(_), do: :ok

  defp validate_agent_type(%{agent_type: nil}), do: {:error, :missing_agent_type}

  defp validate_agent_type(%{agent_type: type}) do
    case Thalamus.Domain.ValueObjects.AgentType.new(type) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :invalid_agent_type}
    end
  end

  defp validate_task_scopes(%{task_scopes: []}), do: {:error, :empty_task_scopes}
  defp validate_task_scopes(%{task_scopes: scopes}) when is_list(scopes), do: :ok
  defp validate_task_scopes(_), do: {:error, :invalid_task_scopes}

  defp validate_ttl(%{ttl: nil}), do: :ok
  defp validate_ttl(%{ttl: ttl}) when is_integer(ttl) and ttl > 0, do: :ok
  defp validate_ttl(_), do: {:error, :invalid_ttl}
end
