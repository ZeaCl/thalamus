defmodule Thalamus.Application.DTOs.AgentTokenResponse do
  @moduledoc """
  Data Transfer Object for agent token generation responses.

  Extends standard OAuth2 token response with agent-specific metadata.
  """

  @type t :: %__MODULE__{
          # OAuth2 Standard Fields
          access_token: String.t(),
          # Always "Bearer"
          token_type: String.t(),
          expires_in: non_neg_integer(),
          # Space-separated scopes
          scope: String.t(),

          # Agent-Specific Metadata
          agent_type: String.t(),
          task_id: String.t() | nil,
          max_operations: non_neg_integer() | nil,
          expires_on_completion: boolean()
        }

  defstruct [
    :access_token,
    :expires_in,
    :scope,
    :agent_type,
    :task_id,
    :max_operations,
    token_type: "Bearer",
    expires_on_completion: false
  ]

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
      max_operations: response.max_operations,
      expires_on_completion: response.expires_on_completion
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
