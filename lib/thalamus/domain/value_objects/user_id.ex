defmodule Thalamus.Domain.ValueObjects.UserId do
  @moduledoc """
  Value Object representing a unique user identifier.

  SOLID Principles Applied:
  - Single Responsibility: Only handles user ID validation and formatting
  - Open/Closed: Can be extended for different ID formats without modification
  """

  @type t :: %__MODULE__{
          value: String.t()
        }

  defstruct [:value]

  @doc """
  Creates a new UserId.

  ## Examples

      iex> Thalamus.Domain.ValueObjects.UserId.new("user_12345")
      {:ok, %Thalamus.Domain.ValueObjects.UserId{value: "user_12345"}}

      iex> Thalamus.Domain.ValueObjects.UserId.new("")
      {:error, :invalid_user_id}

      iex> Thalamus.Domain.ValueObjects.UserId.new(nil)
      {:error, :invalid_user_id}
  """
  def new(value) when is_binary(value) and value != "" do
    case validate_format(value) do
      :ok -> {:ok, %__MODULE__{value: value}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :invalid_user_id}

  @doc """
  Generates a new unique UserId.

  ## Examples

      iex> {:ok, %Thalamus.Domain.ValueObjects.UserId{value: value}} = Thalamus.Domain.ValueObjects.UserId.generate()
      iex> String.starts_with?(value, "user_")
      true
  """
  def generate do
    uuid = UUID.uuid4()
    new("user_#{uuid}")
  end

  @doc """
  Converts UserId to string for database storage or API responses.

  ## Examples

      iex> user_id = %Thalamus.Domain.ValueObjects.UserId{value: "user_12345"}
      iex> Thalamus.Domain.ValueObjects.UserId.to_string(user_id)
      "user_12345"
  """
  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  Creates UserId from string (for database loading).

  ## Examples

      iex> Thalamus.Domain.ValueObjects.UserId.from_string("user_12345")
      {:ok, %Thalamus.Domain.ValueObjects.UserId{value: "user_12345"}}
  """
  def from_string(value), do: new(value)

  # Private functions

  defp validate_format(value) do
    cond do
      String.length(value) < 3 ->
        {:error, :user_id_too_short}

      String.length(value) > 100 ->
        {:error, :user_id_too_long}

      not String.match?(value, ~r/^[a-zA-Z0-9_-]+$/) ->
        {:error, :invalid_user_id_format}

      true ->
        :ok
    end
  end
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.UserId do
  def to_string(%Thalamus.Domain.ValueObjects.UserId{value: value}), do: value
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.UserId do
  def encode(%Thalamus.Domain.ValueObjects.UserId{value: value}, opts) do
    Jason.Encode.string(value, opts)
  end
end