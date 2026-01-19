defmodule Thalamus.Domain.ValueObjects.OrganizationId do
  @moduledoc """
  Value Object representing a unique organization identifier.

  SOLID Principles Applied:
  - Single Responsibility: Only handles organization ID validation and formatting
  - Open/Closed: Can be extended for different ID formats without modification
  """

  @type t :: %__MODULE__{
          value: String.t()
        }

  defstruct [:value]

  @doc """
  Creates a new OrganizationId.

  ## Examples

      iex> OrganizationId.new("org_12345")
      {:ok, %OrganizationId{value: "org_12345"}}

      iex> OrganizationId.new("")
      {:error, :invalid_organization_id}

      iex> OrganizationId.new(nil)
      {:error, :invalid_organization_id}
  """
  def new(value) when is_binary(value) and value != "" do
    case validate_format(value) do
      :ok -> {:ok, %__MODULE__{value: value}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :invalid_organization_id}

  @doc """
  Generates a new unique OrganizationId.

  ## Examples

      iex> OrganizationId.generate()
      {:ok, %OrganizationId{value: "org_" <> _uuid}}
  """
  def generate do
    uuid = UUID.uuid4()
    new("org_#{uuid}")
  end

  @doc """
  Generates a new unique OrganizationId, raising on error.

  ## Examples

      iex> %OrganizationId{value: value} = OrganizationId.generate!()
      iex> String.starts_with?(value, "org_")
      true
  """
  def generate! do
    {:ok, org_id} = generate()
    org_id
  end

  @doc """
  Converts OrganizationId to string for database storage or API responses.

  ## Examples

      iex> org_id = %OrganizationId{value: "org_12345"}
      iex> OrganizationId.to_string(org_id)
      "org_12345"
  """
  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  Creates OrganizationId from string (for database loading).

  ## Examples

      iex> OrganizationId.from_string("org_12345")
      {:ok, %OrganizationId{value: "org_12345"}}
  """
  def from_string(value), do: new(value)

  # Private functions

  defp validate_format(value) do
    cond do
      String.length(value) < 3 ->
        {:error, :organization_id_too_short}

      String.length(value) > 100 ->
        {:error, :organization_id_too_long}

      not String.match?(value, ~r/^[a-zA-Z0-9_-]+$/) ->
        {:error, :invalid_organization_id_format}

      true ->
        :ok
    end
  end
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.OrganizationId do
  def to_string(%Thalamus.Domain.ValueObjects.OrganizationId{value: value}), do: value
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.OrganizationId do
  def encode(%Thalamus.Domain.ValueObjects.OrganizationId{value: value}, opts) do
    Jason.Encode.string(value, opts)
  end
end

# Implement Phoenix.Param protocol for URL generation
defimpl Phoenix.Param, for: Thalamus.Domain.ValueObjects.OrganizationId do
  def to_param(%Thalamus.Domain.ValueObjects.OrganizationId{value: value}), do: value
end
