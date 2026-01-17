defmodule Thalamus.Domain.ValueObjects.DelegationChain do
  @moduledoc """
  Value Object representing an agent token delegation chain.

  Tracks the hierarchy of token delegations to prevent infinite delegation
  and maintain auditability.

  SOLID Principles Applied:
  - Single Responsibility: Only manages delegation chain state and validation
  - Open/Closed: Extensible via protocols without modifying core logic
  """

  @type t :: %__MODULE__{
          parent_token_id: String.t() | nil,
          depth: non_neg_integer(),
          path: [String.t()]
        }

  @max_depth 4

  defstruct [:parent_token_id, :depth, :path]

  @doc """
  Creates a new DelegationChain value object.

  ## Fields

  - `parent_token_id` - UUID of the parent token (nil for root tokens)
  - `depth` - Delegation depth (0 for root, max #{@max_depth})
  - `path` - List of token IDs from root to current (ordered)

  ## Examples

      iex> DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
      {:ok, %DelegationChain{parent_token_id: nil, depth: 0, path: []}}

      iex> DelegationChain.new(%{parent_token_id: "token-1", depth: 1, path: ["token-1"]})
      {:ok, %DelegationChain{parent_token_id: "token-1", depth: 1, path: ["token-1"]}}

      iex> DelegationChain.new(%{parent_token_id: "token-5", depth: 5, path: ["token-1", "token-2", "token-3", "token-4", "token-5"]})
      {:error, :max_delegation_depth_exceeded}
  """
  @spec new(map()) :: {:ok, t()} | {:error, atom()}
  def new(%{parent_token_id: parent_id, depth: depth, path: path} = attrs)
      when is_map(attrs) do
    with :ok <- validate_depth(depth),
         :ok <- validate_path(path, depth) do
      {:ok, %__MODULE__{parent_token_id: parent_id, depth: depth, path: path}}
    end
  end

  def new(_), do: {:error, :invalid_delegation_chain}

  @doc """
  Creates a root delegation chain (no parent).

  Convenience function for creating a root chain without specifying all fields.

  ## Examples

      iex> DelegationChain.from_delegator("user-123")
      {:ok, %DelegationChain{parent_token_id: nil, depth: 0, path: []}}
  """
  @spec from_delegator(any()) :: {:ok, t()} | {:error, atom()}
  def from_delegator(_delegator_id) do
    new(%{parent_token_id: nil, depth: 0, path: []})
  end

  @doc """
  Checks if delegation chain exceeds maximum depth.

  Returns true if depth is >= #{@max_depth + 1}, false otherwise.
  """
  @spec exceeds_max_depth?(t()) :: boolean()
  def exceeds_max_depth?(%__MODULE__{depth: depth}), do: depth > @max_depth

  @doc """
  Checks if this is a root delegation chain (no parent).
  """
  @spec root?(t()) :: boolean()
  def root?(%__MODULE__{parent_token_id: nil, depth: 0}), do: true
  def root?(_), do: false

  @doc """
  Adds a new delegation to the chain.

  Returns error if adding would exceed maximum depth.

  ## Examples

      iex> {:ok, root} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
      iex> DelegationChain.add_delegation(root, "token-1")
      {:ok, %DelegationChain{parent_token_id: "token-1", depth: 1, path: ["token-1"]}}
  """
  @spec add_delegation(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def add_delegation(%__MODULE__{depth: depth}, _token_id) when depth >= @max_depth do
    {:error, :max_delegation_depth_exceeded}
  end

  def add_delegation(%__MODULE__{depth: depth, path: path}, token_id) do
    new(%{
      parent_token_id: token_id,
      depth: depth + 1,
      path: path ++ [token_id]
    })
  end

  # Private validation functions

  defp validate_depth(depth) when is_integer(depth) and depth >= 0 and depth <= @max_depth do
    :ok
  end

  defp validate_depth(depth) when is_integer(depth) and depth > @max_depth do
    {:error, :max_delegation_depth_exceeded}
  end

  defp validate_depth(_), do: {:error, :invalid_delegation_chain}

  defp validate_path(path, depth) when is_list(path) do
    cond do
      length(path) != depth ->
        {:error, :invalid_delegation_chain}

      depth == 0 and path == [] ->
        :ok

      Enum.any?(path, fn item -> is_nil(item) or item == "" end) ->
        {:error, :invalid_delegation_chain}

      true ->
        :ok
    end
  end

  defp validate_path(_, _), do: {:error, :invalid_delegation_chain}

  @doc "Converts DelegationChain to string representation"
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{parent_token_id: nil, depth: 0}) do
    "root (depth: 0)"
  end

  def to_string(%__MODULE__{parent_token_id: parent_id, depth: depth}) do
    "delegated from #{parent_id} (depth: #{depth})"
  end
end

# Protocol implementations
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.DelegationChain do
  def to_string(chain) do
    Thalamus.Domain.ValueObjects.DelegationChain.to_string(chain)
  end
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.DelegationChain do
  def encode(%{parent_token_id: parent_id, depth: depth, path: path}, opts) do
    Jason.Encode.map(
      %{
        parent_token_id: parent_id,
        depth: depth,
        path: path
      },
      opts
    )
  end
end
