defmodule Thalamus.Domain.ValueObjects.TaskId do
  @moduledoc """
  Value Object representing a unique task identifier (UUID).

  SOLID Principles Applied:
  - Single Responsibility: Only validates and represents task UUIDs
  - Open/Closed: Extensible via protocols without modifying core logic
  """

  @type t :: %__MODULE__{value: String.t()}

  defstruct [:value]

  @doc """
  Creates a new TaskId value object from a UUID string.

  Accepts UUIDs in various formats:
  - With dashes: "550e8400-e29b-41d4-a716-446655440000"
  - Without dashes: "550e8400e29b41d4a716446655440000"
  - Any case: uppercase, lowercase, or mixed

  Always normalizes to lowercase with dashes.

  ## Examples

      iex> TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, %TaskId{value: "550e8400-e29b-41d4-a716-446655440000"}}

      iex> TaskId.new("550E8400-E29B-41D4-A716-446655440000")
      {:ok, %TaskId{value: "550e8400-e29b-41d4-a716-446655440000"}}

      iex> TaskId.new("not-a-uuid")
      {:error, :invalid_task_id}
  """
  @spec new(any()) :: {:ok, t()} | {:error, atom()}
  def new(value) when is_binary(value) do
    # Reject strings with leading/trailing whitespace
    if String.trim(value) != value do
      {:error, :invalid_task_id}
    else
      normalized = normalize_uuid(value)

      case Ecto.UUID.cast(normalized) do
        {:ok, uuid} -> {:ok, %__MODULE__{value: uuid}}
        :error -> {:error, :invalid_task_id}
      end
    end
  end

  def new(_), do: {:error, :invalid_task_id}

  # Convert UUID to lowercase and add dashes if missing
  defp normalize_uuid(value) do
    downcased = String.downcase(value)

    # If UUID has no dashes, add them in the correct positions
    # UUID format: 8-4-4-4-12
    if String.contains?(downcased, "-") do
      downcased
    else
      case String.length(downcased) do
        32 ->
          <<p1::binary-size(8), p2::binary-size(4), p3::binary-size(4), p4::binary-size(4),
            p5::binary-size(12)>> = downcased

          "#{p1}-#{p2}-#{p3}-#{p4}-#{p5}"

        _ ->
          downcased
      end
    end
  end

  @doc "Converts TaskId to UUID string representation"
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value
end

# Protocol implementations
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.TaskId do
  def to_string(%{value: value}), do: value
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.TaskId do
  def encode(%{value: value}, opts) do
    Jason.Encode.string(value, opts)
  end
end
