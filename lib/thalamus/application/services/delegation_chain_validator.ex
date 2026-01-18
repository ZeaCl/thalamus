defmodule Thalamus.Application.Services.DelegationChainValidator do
  @moduledoc """
  Service for validating delegation chains for agent tokens.

  SOLID Principles Applied:
  - Single Responsibility: Only handles delegation chain validation logic
  - Open/Closed: Can be extended with new validation rules
  - Dependency Inversion: Depends on UserRepository port, not implementation

  ## Validation Rules

  1. **Depth Limit**: Chain cannot exceed maximum depth (default: 10)
  2. **User Existence**: All users in chain must exist in the system
  3. **User Active Status**: All users in chain must be active
  4. **Valid UUIDs**: All user IDs must be valid UUIDs
  5. **No Circular Delegation**: Same user cannot appear twice in chain

  Per 03-tasks.md Epic 3.2 specification.
  """

  alias Thalamus.Domain.ValueObjects.DelegationChain

  @type validation_result :: :ok | {:error, atom()}
  @type deps :: %{user_repository: module()}

  # Maximum delegation depth
  @max_depth 10

  @doc """
  Validates a delegation chain comprehensively.

  ## Parameters

  - `chain` - DelegationChain value object
  - `deps` - Dependencies map with :user_repository

  ## Returns

  - `:ok` - Chain is valid
  - `{:error, :delegation_chain_too_deep}` - Exceeds max depth
  - `{:error, :invalid_user_id_in_chain}` - Contains invalid UUID
  - `{:error, :empty_delegation_chain}` - Chain is empty (when required)
  - `{:error, :circular_delegation}` - Same user appears multiple times
  - `{:error, {:user_not_found, user_id}}` - User doesn't exist
  - `{:error, {:user_inactive, user_id}}` - User is not active

  ## Examples

      iex> {:ok, chain} = DelegationChain.from_delegator(user_id)
      iex> DelegationChainValidator.validate(chain, deps)
      :ok
  """
  @spec validate(DelegationChain.t(), deps()) :: validation_result()
  def validate(%DelegationChain{} = chain, deps) do
    with :ok <- validate_depth(chain),
         :ok <- validate_no_circular_delegation(chain),
         :ok <- validate_user_ids_format(chain),
         :ok <- validate_users_exist(chain, deps),
         :ok <- validate_users_active(chain, deps) do
      :ok
    end
  end

  @doc """
  Validates only the depth of a delegation chain.

  Useful for quick checks before full validation.

  ## Parameters

  - `chain` - DelegationChain value object

  ## Returns

  - `:ok` - Depth is valid
  - `{:error, :delegation_chain_too_deep}` - Exceeds maximum depth
  """
  @spec validate_depth(DelegationChain.t()) :: validation_result()
  def validate_depth(%DelegationChain{chain: chain}) do
    if length(chain) <= @max_depth do
      :ok
    else
      {:error, :delegation_chain_too_deep}
    end
  end

  @doc """
  Validates that no user appears twice in the delegation chain.

  Prevents circular delegation attacks where user A delegates to B,
  which delegates back to A.

  ## Parameters

  - `chain` - DelegationChain value object

  ## Returns

  - `:ok` - No circular delegation
  - `{:error, :circular_delegation}` - User appears multiple times
  """
  @spec validate_no_circular_delegation(DelegationChain.t()) :: validation_result()
  def validate_no_circular_delegation(%DelegationChain{chain: chain}) do
    unique_count =
      chain
      |> Enum.map(&normalize_user_id/1)
      |> Enum.uniq()
      |> length()

    if unique_count == length(chain) do
      :ok
    else
      {:error, :circular_delegation}
    end
  end

  @doc """
  Validates that all user IDs in the chain are valid UUIDs.

  ## Parameters

  - `chain` - DelegationChain value object

  ## Returns

  - `:ok` - All IDs are valid UUIDs
  - `{:error, :invalid_user_id_in_chain}` - Contains invalid UUID
  """
  @spec validate_user_ids_format(DelegationChain.t()) :: validation_result()
  def validate_user_ids_format(%DelegationChain{chain: chain}) do
    all_valid? =
      Enum.all?(chain, fn user_id ->
        user_id
        |> normalize_user_id()
        |> valid_uuid?()
      end)

    if all_valid? do
      :ok
    else
      {:error, :invalid_user_id_in_chain}
    end
  end

  @doc """
  Validates that all users in the chain exist in the system.

  ## Parameters

  - `chain` - DelegationChain value object
  - `deps` - Dependencies map with :user_repository

  ## Returns

  - `:ok` - All users exist
  - `{:error, {:user_not_found, user_id}}` - User doesn't exist
  """
  @spec validate_users_exist(DelegationChain.t(), deps()) :: validation_result()
  def validate_users_exist(%DelegationChain{chain: []}, _deps), do: :ok

  def validate_users_exist(%DelegationChain{chain: chain}, deps) do
    Enum.reduce_while(chain, :ok, fn user_id, :ok ->
      normalized_id = normalize_user_id(user_id)

      case deps.user_repository.find_by_id(normalized_id) do
        {:ok, _user} ->
          {:cont, :ok}

        {:error, :not_found} ->
          {:halt, {:error, {:user_not_found, normalized_id}}}

        {:error, _reason} ->
          {:halt, {:error, {:user_not_found, normalized_id}}}
      end
    end)
  end

  @doc """
  Validates that all users in the chain are active.

  ## Parameters

  - `chain` - DelegationChain value object
  - `deps` - Dependencies map with :user_repository

  ## Returns

  - `:ok` - All users are active
  - `{:error, {:user_inactive, user_id}}` - User is inactive
  """
  @spec validate_users_active(DelegationChain.t(), deps()) :: validation_result()
  def validate_users_active(%DelegationChain{chain: []}, _deps), do: :ok

  def validate_users_active(%DelegationChain{chain: chain}, deps) do
    Enum.reduce_while(chain, :ok, fn user_id, :ok ->
      normalized_id = normalize_user_id(user_id)

      case deps.user_repository.find_by_id(normalized_id) do
        {:ok, user} ->
          if user_active?(user) do
            {:cont, :ok}
          else
            {:halt, {:error, {:user_inactive, normalized_id}}}
          end

        {:error, _} ->
          # User doesn't exist - will be caught by validate_users_exist
          {:cont, :ok}
      end
    end)
  end

  @doc """
  Builds a delegation chain from a delegator user ID.

  Wrapper around DelegationChain.from_delegator with validation.

  ## Parameters

  - `delegator_id` - User ID string (UUID format)
  - `deps` - Dependencies map with :user_repository (optional for validation)

  ## Returns

  - `{:ok, DelegationChain.t()}` - Valid delegation chain
  - `{:error, reason}` - Validation failed
  """
  @spec build_chain(String.t(), deps() | nil) :: {:ok, DelegationChain.t()} | {:error, atom()}
  def build_chain(delegator_id, deps \\ nil) when is_binary(delegator_id) do
    with {:ok, chain} <- DelegationChain.from_delegator(delegator_id),
         :ok <- maybe_validate(chain, deps) do
      {:ok, chain}
    end
  end

  # --- Private Helper Functions ---

  defp normalize_user_id(%{value: id}), do: id
  defp normalize_user_id(id) when is_binary(id), do: id

  defp valid_uuid?(string) when is_binary(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp valid_uuid?(_), do: false

  defp user_active?(%{status: :active}), do: true
  defp user_active?(%{is_active: true}), do: true
  defp user_active?(_), do: false

  defp maybe_validate(_chain, nil), do: :ok

  defp maybe_validate(chain, deps) do
    validate(chain, deps)
  end
end
