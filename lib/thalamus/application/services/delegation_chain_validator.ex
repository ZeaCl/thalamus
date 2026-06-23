defmodule Thalamus.Application.Services.DelegationChainValidator do
  @moduledoc """
  Service for validating delegation chains for agent tokens.

  SOLID Principles Applied:
  - Single Responsibility: Only handles delegation chain validation logic
  - Open/Closed: Can be extended with new validation rules
  - Dependency Inversion: Depends on AgentTokenRepository port, not implementation

  ## Validation Rules

  1. **Parent Token Existence**: Parent token must exist if parent_id is provided
  2. **Parent Token Active Status**: Parent token must be active (not revoked, not expired)
  3. **Parent Token Scopes**: Child token scopes must be a subset of parent token scopes
  4. **Delegation Depth**: Delegation depth must be less than 5 (checked by add_delegation)
  """

  alias Thalamus.Domain.ValueObjects.DelegationChain
  alias Thalamus.Domain.Entities.AgentToken

  @type validation_result :: {:ok, DelegationChain.t()} | {:error, atom()}
  @type deps :: %{
          agent_token_repository: module()
        }

  @doc """
  Validates a delegation parent token and returns the child delegation chain.

  ## Parameters

  - `parent_agent_id` - UUID of the parent agent token (nil if root)
  - `requested_scopes` - Scopes requested for the child token
  - `deps` - Dependencies map with :agent_token_repository

  ## Returns

  - `{:ok, delegation_chain}` - Valid delegation chain for child token
  - `{:error, reason}` - Validation failed
  """
  @spec validate(String.t() | nil, [String.t()], deps()) :: validation_result()
  def validate(nil, _requested_scopes, _deps) do
    # Root token - no parent to validate
    DelegationChain.new(%{
      parent_token_id: nil,
      depth: 0,
      path: []
    })
  end

  def validate(parent_id, requested_scopes, %{agent_token_repository: repo})
      when is_binary(parent_id) do
    with {:ok, parent_token} <- repo.find_by_id(parent_id),
         :ok <- validate_active(parent_token),
         :ok <- validate_scopes_subset(requested_scopes, parent_token.scopes),
         {:ok, child_chain} <-
           DelegationChain.add_delegation(parent_token.delegation_chain, parent_id) do
      {:ok, child_chain}
    else
      {:error, :not_found} -> {:error, :parent_token_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_active(parent_token) do
    if AgentToken.active?(parent_token) do
      :ok
    else
      {:error, :parent_token_not_active}
    end
  end

  defp validate_scopes_subset(requested_scopes, parent_scopes) do
    requested_set = MapSet.new(requested_scopes)
    parent_set = MapSet.new(parent_scopes)

    if MapSet.subset?(requested_set, parent_set) do
      :ok
    else
      {:error, :scopes_exceed_parent}
    end
  end
end
