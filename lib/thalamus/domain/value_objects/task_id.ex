defmodule Thalamus.Domain.ValueObjects.TaskId do
  @moduledoc """
  Value Object representing a task identifier.

  Format: External task ID from orchestrator (e.g., "task_abc123", "job-456")

  SOLID Principles Applied:
  - Single Responsibility: Only validates task ID format
  """

  @type t :: %__MODULE__{value: String.t()}

  defstruct [:value]

  @max_length 255
  @min_length 1

  @doc """
  Creates a new TaskId value object.

  ## Validation Rules

  - Length: 1-255 characters
  - Format: Alphanumeric, hyphens, underscores only

  ## Examples

      iex> TaskId.new("task_abc123")
      {:ok, %TaskId{value: "task_abc123"}}

      iex> TaskId.new("task with spaces")
      {:error, :invalid_task_id_format}
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, atom()}
  def new(value) when is_binary(value) do
    with :ok <- validate_length(value),
         :ok <- validate_format(value) do
      {:ok, %__MODULE__{value: value}}
    end
  end

  def new(_), do: {:error, :invalid_task_id}

  defp validate_length(value) do
    cond do
      String.length(value) < @min_length ->
        {:error, :task_id_too_short}

      String.length(value) > @max_length ->
        {:error, :task_id_too_long}

      true ->
        :ok
    end
  end

  defp validate_format(value) do
    if String.match?(value, ~r/^[a-zA-Z0-9_-]+$/) do
      :ok
    else
      {:error, :invalid_task_id_format}
    end
  end

  @doc "Converts TaskId to string"
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
