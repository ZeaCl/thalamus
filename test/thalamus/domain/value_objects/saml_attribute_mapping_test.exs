defmodule Thalamus.Domain.ValueObjects.SamlAttributeMappingTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.SamlAttributeMapping

  describe "new/1" do
    test "accepts valid attribute mapping" do
      mapping = %{"email" => "emailaddress", "name" => "displayname"}
      assert {:ok, %SamlAttributeMapping{mappings: ^mapping}} = SamlAttributeMapping.new(mapping)
    end

    test "accepts empty mapping" do
      assert {:ok, %SamlAttributeMapping{mappings: %{}}} = SamlAttributeMapping.new(%{})
    end

    test "accepts mapping with avatar_url" do
      mapping = %{"email" => "emailaddress", "avatar_url" => "photo"}
      assert {:ok, %SamlAttributeMapping{mappings: ^mapping}} = SamlAttributeMapping.new(mapping)
    end

    test "rejects invalid field keys" do
      assert {:error, :invalid_attribute_mapping_keys} =
               SamlAttributeMapping.new(%{"invalid_field" => "some_attr"})
    end

    test "rejects non-map input" do
      assert {:error, :invalid_mapping} = SamlAttributeMapping.new("not_a_map")
    end
  end

  describe "attribute_for/2" do
    setup do
      {:ok, mapping} =
        SamlAttributeMapping.new(%{"email" => "emailaddress", "name" => "displayname"})

      %{mapping: mapping}
    end

    test "returns the SAML attribute name for a mapped field", %{mapping: mapping} do
      assert SamlAttributeMapping.attribute_for(mapping, "email") == "emailaddress"
      assert SamlAttributeMapping.attribute_for(mapping, "name") == "displayname"
    end

    test "returns nil for unmapped field", %{mapping: mapping} do
      assert SamlAttributeMapping.attribute_for(mapping, "avatar_url") == nil
    end
  end
end
