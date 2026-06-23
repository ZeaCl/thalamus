defmodule Thalamus.Domain.ValueObjects.SamlNameId do
  @moduledoc """
  Value Object for SAML NameID extracted from assertions.

  The NameID identifies the authenticated user within the SAML assertion.
  Common formats: email, persistent, transient, unspecified.

  SOLID: Single Responsibility — only validates SAML NameID values.
  """

  @valid_formats [:email, :persistent, :transient, :unspecified, :entity]

  @type format :: :email | :persistent | :transient | :unspecified | :entity
  @type t :: %__MODULE__{value: String.t(), format: format()}

  defstruct [:value, :format]

  @doc """
  Creates a new SamlNameId value object.

  ## Examples

      iex> SamlNameId.new("user@example.com", :email)
      {:ok, %SamlNameId{value: "user@example.com", format: :email}}

      iex> SamlNameId.new("", :email)
      {:error, :empty_name_id}

      iex> SamlNameId.new("user@example.com", :invalid_format)
      {:error, :invalid_name_id}
  """
  @spec new(String.t(), format()) :: {:ok, t()} | {:error, atom()}
  def new(value, format \\ :email)

  def new(value, format) when is_binary(value) and format in @valid_formats do
    if byte_size(value) > 0 do
      {:ok, %__MODULE__{value: value, format: format}}
    else
      {:error, :empty_name_id}
    end
  end

  def new(_, _), do: {:error, :invalid_name_id}
end

defimpl String.Chars, for: Thalamus.Domain.ValueObjects.SamlNameId do
  def to_string(%{value: value}), do: value
end
