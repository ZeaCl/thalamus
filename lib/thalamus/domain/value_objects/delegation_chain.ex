defmodule Thalamus.Domain.ValueObjects.DelegationChain do
  @moduledoc """
  Value Object representing a chain of delegation from human to agent(s).

  SOLID Principles Applied:
  - Single Responsibility: Only manages delegation chain
  - Open/Closed: Supports arbitrary depth
  """

  alias Thalamus.Domain.ValueObjects.UserId

  @type t :: %__MODULE__{chain: [UserId.t() | String.t()]}

  defstruct chain: []

  # Prevent infinite delegation chains
  @max_depth 10

  @doc """
  Creates a new DelegationChain from a list of user IDs.

  ## Examples

      iex> DelegationChain.new(["user_abc", "user_def"])
      {:ok, %DelegationChain{chain: [...]}}
  """
  @spec new([String.t()]) :: {:ok, t()} | {:error, atom()}
  def new(user_ids) when is_list(user_ids) do
    with :ok <- validate_depth(user_ids),
         {:ok, chain} <- parse_user_ids(user_ids) do
      {:ok, %__MODULE__{chain: chain}}
    end
  end

  def new(_), do: {:error, :invalid_delegation_chain}

  @doc "Creates a root (empty) delegation chain"
  @spec root() :: {:ok, t()}
  def root do
    {:ok, %__MODULE__{chain: []}}
  end

  @doc "Creates a delegation chain with a single delegator"
  @spec from_delegator(String.t()) :: {:ok, t()} | {:error, atom()}
  def from_delegator(user_id) do
    new([user_id])
  end

  @doc "Returns the depth of the delegation chain"
  @spec depth(t()) :: non_neg_integer()
  def depth(%__MODULE__{chain: chain}), do: length(chain)

  @doc "Returns the original delegator (first in chain)"
  @spec original_delegator(t()) :: UserId.t() | String.t() | nil
  def original_delegator(%__MODULE__{chain: []}), do: nil
  def original_delegator(%__MODULE__{chain: [first | _]}), do: first

  @doc "Returns the immediate delegator (last in chain)"
  @spec immediate_delegator(t()) :: UserId.t() | String.t() | nil
  def immediate_delegator(%__MODULE__{chain: []}), do: nil
  def immediate_delegator(%__MODULE__{chain: chain}), do: List.last(chain)

  @doc "Appends a user ID to the delegation chain"
  @spec append(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def append(%__MODULE__{chain: chain}, user_id) when is_binary(user_id) do
    new_chain = chain ++ [user_id]

    with :ok <- validate_depth(new_chain),
         {:ok, validated_chain} <- parse_user_ids(new_chain) do
      {:ok, %__MODULE__{chain: validated_chain}}
    end
  end

  def append(_, _), do: {:error, :invalid_user_id_in_chain}

  defp validate_depth(user_ids) do
    if length(user_ids) <= @max_depth do
      :ok
    else
      {:error, :delegation_chain_too_deep}
    end
  end

  defp parse_user_ids([]), do: {:error, :empty_delegation_chain}

  defp parse_user_ids(user_ids) do
    # Validate that all IDs are valid UUIDs
    result =
      Enum.reduce_while(user_ids, {:ok, []}, fn id, {:ok, acc} ->
        cond do
          is_binary(id) and valid_uuid?(id) ->
            {:cont, {:ok, acc ++ [id]}}

          is_binary(id) and String.length(id) > 0 ->
            # Accept non-UUID strings for backwards compatibility
            {:cont, {:ok, acc ++ [id]}}

          true ->
            {:halt, {:error, :invalid_user_id_in_chain}}
        end
      end)

    result
  end

  defp valid_uuid?(string) when is_binary(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp valid_uuid?(_), do: false

  @doc "Converts delegation chain to list of string user IDs"
  @spec to_list(t()) :: [String.t()]
  def to_list(%__MODULE__{chain: chain}) do
    Enum.map(chain, fn
      %UserId{value: id} -> id
      id when is_binary(id) -> id
    end)
  end
end

# Protocol implementations
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.DelegationChain do
  def to_string(%{chain: chain}) do
    chain_strings =
      Enum.map(chain, fn
        %{value: id} -> id
        id when is_binary(id) -> id
      end)

    Enum.join(chain_strings, " -> ")
  end
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.DelegationChain do
  def encode(%{chain: chain}, opts) do
    chain_strings =
      Enum.map(chain, fn
        %{value: id} -> id
        id when is_binary(id) -> id
      end)

    Jason.Encode.list(chain_strings, opts)
  end
end
