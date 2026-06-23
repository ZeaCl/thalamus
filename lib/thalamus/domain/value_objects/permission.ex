defmodule Thalamus.Domain.ValueObjects.Permission do
  @moduledoc """
  Value Object representing a permission scope.

  Supports multiple scope formats for agentic workflows:
  - OIDC standard: `openid`, `profile`, `email`
  - Namespaced: `api:read`, `data:write`
  - MCP servers: `mcp:gmail:read`, `mcp:slack:write`
  - Multi-level: `mcp:slack:channels:list` (max 4 levels)

  SOLID Principles:
  - Single Responsibility: Only validates scope format
  - Open/Closed: Extensible via regex pattern updates
  """

  @type t :: %__MODULE__{value: String.t()}
  defstruct [:value]

  # Matches: single word OR colon-separated (max 4 levels)
  # Examples:
  #   openid               ✓
  #   api:read             ✓
  #   mcp:gmail:read       ✓
  #   mcp:slack:channels:list  ✓
  @scope_regex ~r/^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){0,3}$/

  @max_length 128

  @doc """
  Creates a new Permission value object from a scope string.

  ## Examples

      iex> Permission.new("openid")
      {:ok, %Permission{value: "openid"}}

      iex> Permission.new("api:read")
      {:ok, %Permission{value: "api:read"}}

      iex> Permission.new("mcp:gmail:read")
      {:ok, %Permission{value: "mcp:gmail:read"}}

      iex> Permission.new("mcp:slack:channels:list")
      {:ok, %Permission{value: "mcp:slack:channels:list"}}

      iex> Permission.new("invalid scope!")
      {:error, :invalid_scope_format}

      iex> Permission.new(String.duplicate("a", 130))
      {:error, :scope_too_long}
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, atom()}
  def new(scope) when is_binary(scope) do
    cond do
      String.length(scope) > @max_length ->
        {:error, :scope_too_long}

      not valid_format?(scope) ->
        {:error, :invalid_scope_format}

      true ->
        {:ok, %__MODULE__{value: scope}}
    end
  end

  def new(_), do: {:error, :invalid_scope_format}

  @doc """
  Validates a scope string format without creating the value object.

  ## Examples

      iex> Permission.valid_format?("openid")
      true

      iex> Permission.valid_format?("mcp:gmail:read")
      true

      iex> Permission.valid_format?("invalid!")
      false
  """
  @spec valid_format?(String.t()) :: boolean()
  def valid_format?(scope) when is_binary(scope) do
    Regex.match?(@scope_regex, scope)
  end

  def valid_format?(_), do: false

  @doc """
  Converts the Permission to its string representation.

  ## Examples

      iex> {:ok, perm} = Permission.new("api:read")
      iex> Permission.to_string(perm)
      "api:read"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value
end

# Protocol implementations
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.Permission do
  def to_string(%{value: value}), do: value
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.Permission do
  def encode(%{value: value}, opts), do: Jason.Encode.string(value, opts)
end
