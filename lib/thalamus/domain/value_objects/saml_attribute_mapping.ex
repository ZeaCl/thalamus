defmodule Thalamus.Domain.ValueObjects.SamlAttributeMapping do
  @moduledoc """
  Value Object for SAML attribute → User field mapping.

  Maps SAML assertion attribute names to User entity fields.
  Example: %{"email" => "emailaddress", "name" => "displayname"}

  SOLID: Single Responsibility — only validates attribute mapping keys.
  """

  @allowed_fields ~w(email name avatar_url)

  @type t :: %__MODULE__{mappings: map()}
  defstruct mappings: %{}

  @doc """
  Creates a new SamlAttributeMapping value object.

  ## Examples

      iex> SamlAttributeMapping.new(%{"email" => "emailaddress", "name" => "displayname"})
      {:ok, %SamlAttributeMapping{mappings: %{"email" => "emailaddress", "name" => "displayname"}}}

      iex> SamlAttributeMapping.new(%{"invalid_field" => "some_attr"})
      {:error, :invalid_attribute_mapping_keys}

      iex> SamlAttributeMapping.new(%{})
      {:ok, %SamlAttributeMapping{mappings: %{}}}
  """
  @spec new(map()) :: {:ok, t()} | {:error, atom()}
  def new(mapping_map) when is_map(mapping_map) do
    valid_keys =
      mapping_map
      |> Map.keys()
      |> Enum.all?(&(&1 in @allowed_fields))

    if valid_keys do
      {:ok, %__MODULE__{mappings: mapping_map}}
    else
      {:error, :invalid_attribute_mapping_keys}
    end
  end

  def new(_), do: {:error, :invalid_mapping}

  @doc """
  Returns the SAML attribute name for a given user field, or nil if not mapped.

  ## Examples

      iex> mapping = %SamlAttributeMapping{mappings: %{"email" => "emailaddress"}}
      iex> SamlAttributeMapping.attribute_for(mapping, "email")
      "emailaddress"

      iex> SamlAttributeMapping.attribute_for(mapping, "name")
      nil
  """
  @spec attribute_for(t(), String.t()) :: String.t() | nil
  def attribute_for(%__MODULE__{mappings: mappings}, field) do
    Map.get(mappings, field)
  end
end
