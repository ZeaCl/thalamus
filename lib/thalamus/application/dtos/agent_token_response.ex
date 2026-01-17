defmodule Thalamus.Application.DTOs.AgentTokenResponse do
  @moduledoc """
  Data Transfer Object for agent token generation responses.

  Extends standard OAuth2 token response with agent-specific metadata.

  SOLID Principles:
  - Single Responsibility: Only formats agent token responses
  - Open/Closed: Extensible via Jason.Encoder protocol
  """

  @type t :: %__MODULE__{
          # OAuth2 Standard Fields
          access_token: String.t(),
          token_type: String.t(),
          expires_in: non_neg_integer(),
          scope: String.t(),

          # Agent-Specific Metadata
          agent_type: String.t(),
          task_id: String.t(),
          task_description: String.t(),
          delegation_depth: non_neg_integer(),
          reason: String.t() | nil
        }

  defstruct [
    :access_token,
    :expires_in,
    :scope,
    :agent_type,
    :task_id,
    :task_description,
    :delegation_depth,
    :reason,
    token_type: "Bearer"
  ]

  @doc """
  Converts AgentToken domain entity to AgentTokenResponse DTO.

  ## Parameters
  - agent_token: AgentToken domain entity
  - access_token: Generated access token string (from repository)

  ## Returns
  AgentTokenResponse struct ready for JSON serialization
  """
  @spec from_domain(Thalamus.Domain.Entities.AgentToken.t(), String.t()) :: t()
  def from_domain(%Thalamus.Domain.Entities.AgentToken{} = token, access_token) do
    %__MODULE__{
      access_token: access_token,
      token_type: "Bearer",
      expires_in: token.expires_in,
      scope: Enum.join(token.scopes, " "),
      agent_type: Thalamus.Domain.ValueObjects.AgentType.to_string(token.agent_type),
      task_id: Thalamus.Domain.ValueObjects.TaskId.to_string(token.task_id),
      task_description: token.task_description,
      delegation_depth: token.delegation_chain.depth,
      reason: token.reason
    }
  end

  @doc "Converts response to JSON-encodable map"
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = response) do
    %{
      access_token: response.access_token,
      token_type: response.token_type,
      expires_in: response.expires_in,
      scope: response.scope,
      agent_type: response.agent_type,
      task_id: response.task_id,
      task_description: response.task_description,
      delegation_depth: response.delegation_depth,
      reason: response.reason
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
