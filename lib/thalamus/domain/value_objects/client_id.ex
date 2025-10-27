defmodule Thalamus.Domain.ValueObjects.ClientId do
  @moduledoc """
  Value Object representing an OAuth2 client identifier.

  SOLID Principles Applied:
  - Single Responsibility: Only handles client ID validation and formatting
  - Open/Closed: Can be extended for different ID formats without modification
  """

  @type t :: %__MODULE__{
          value: String.t()
        }

  defstruct [:value]

  @doc """
  Creates a new ClientId.

  ## Examples

      iex> ClientId.new("client_12345")
      {:ok, %ClientId{value: "client_12345"}}

      iex> ClientId.new("")
      {:error, :invalid_client_id}

      iex> ClientId.new(nil)
      {:error, :invalid_client_id}
  """
  def new(value) when is_binary(value) and value != "" do
    case validate_format(value) do
      :ok -> {:ok, %__MODULE__{value: value}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :invalid_client_id}

  @doc """
  Generates a new unique ClientId.

  ## Examples

      iex> ClientId.generate()
      {:ok, %ClientId{value: "client_" <> _uuid}}
  """
  def generate do
    uuid = UUID.uuid4()
    new("client_#{uuid}")
  end

  @doc """
  Converts ClientId to string for database storage or API responses.

  ## Examples

      iex> client_id = %ClientId{value: "client_12345"}
      iex> ClientId.to_string(client_id)
      "client_12345"
  """
  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  Creates ClientId from string (for database loading).

  ## Examples

      iex> ClientId.from_string("client_12345")
      {:ok, %ClientId{value: "client_12345"}}
  """
  def from_string(value), do: new(value)

  # Private functions

  defp validate_format(value) do
    cond do
      String.length(value) < 3 ->
        {:error, :client_id_too_short}

      String.length(value) > 100 ->
        {:error, :client_id_too_long}

      not String.match?(value, ~r/^[a-zA-Z0-9_-]+$/) ->
        {:error, :invalid_client_id_format}

      true ->
        :ok
    end
  end
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.ClientId do
  def to_string(%Thalamus.Domain.ValueObjects.ClientId{value: value}), do: value
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.ClientId do
  def encode(%Thalamus.Domain.ValueObjects.ClientId{value: value}, opts) do
    Jason.Encode.string(value, opts)
  end
end