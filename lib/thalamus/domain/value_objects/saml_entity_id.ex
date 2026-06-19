defmodule Thalamus.Domain.ValueObjects.SamlEntityId do
  @moduledoc """
  Value Object for SAML Entity ID.

  Represents the unique identifier of a SAML entity (SP or IdP).
  Typically a URL like "https://sts.windows.net/<tenant-id>/" or a URN.

  SOLID: Single Responsibility — only validates SAML entity ID format.
  """

  @type t :: %__MODULE__{value: String.t()}
  defstruct [:value]

  @doc """
  Creates a new SamlEntityId value object.

  ## Examples

      iex> SamlEntityId.new("https://sts.windows.net/contoso/")
      {:ok, %SamlEntityId{value: "https://sts.windows.net/contoso/"}}

      iex> SamlEntityId.new("urn:example:idp")
      {:ok, %SamlEntityId{value: "urn:example:idp"}}

      iex> SamlEntityId.new("invalid")
      {:error, :invalid_entity_id}
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, atom()}
  def new(value) when is_binary(value) and byte_size(value) > 0 do
    if String.starts_with?(value, "http") or String.starts_with?(value, "urn:") do
      {:ok, %__MODULE__{value: value}}
    else
      {:error, :invalid_entity_id}
    end
  end

  def new(_), do: {:error, :invalid_entity_id}
end

defimpl String.Chars, for: Thalamus.Domain.ValueObjects.SamlEntityId do
  def to_string(%{value: value}), do: value
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.SamlEntityId do
  def encode(%{value: value}, opts), do: Jason.Encode.string(value, opts)
end
