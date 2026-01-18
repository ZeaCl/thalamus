defmodule Thalamus.Domain.ValueObjects.AgentType do
  @moduledoc """
  Value Object representing the type of an AI agent.

  SOLID Principles Applied:
  - Single Responsibility: Only validates agent type
  - Open/Closed: Extensible via new types without modifying existing code
  """

  @type t :: %__MODULE__{value: atom()}

  @valid_types [:autonomous, :supervisor, :tool]

  defstruct [:value]

  @doc """
  Creates a new AgentType value object.

  ## Valid Types (per 03-tasks.md spec)

  - `:autonomous` - Agent operates independently without human approval per action
  - `:supervisor` - Agent that coordinates and delegates to other agents
  - `:tool` - Specialized agent for single-purpose tool execution

  ## Examples

      iex> AgentType.new("autonomous")
      {:ok, %AgentType{value: :autonomous}}

      iex> AgentType.new("invalid")
      {:error, :invalid_agent_type}
  """
  @spec new(String.t() | atom()) :: {:ok, t()} | {:error, atom()}
  def new(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.to_existing_atom()
    |> new()
  rescue
    ArgumentError -> {:error, :invalid_agent_type}
  end

  def new(value) when is_atom(value) do
    if value in @valid_types do
      {:ok, %__MODULE__{value: value}}
    else
      {:error, :invalid_agent_type}
    end
  end

  def new(_), do: {:error, :invalid_agent_type}

  @doc "Returns list of all valid agent types"
  @spec valid_types() :: [atom()]
  def valid_types, do: @valid_types

  @doc "Converts AgentType to string representation"
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: Atom.to_string(value)
end

# Protocol implementations
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.AgentType do
  def to_string(%{value: value}), do: Atom.to_string(value)
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.AgentType do
  def encode(%{value: value}, opts) do
    Jason.Encode.string(Atom.to_string(value), opts)
  end
end
