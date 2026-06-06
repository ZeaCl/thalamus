defmodule Thalamus.Domain.ValueObjects.SamlEntityIdTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.SamlEntityId

  describe "new/1" do
    test "accepts HTTPS URL as entity ID" do
      assert {:ok, %SamlEntityId{value: "https://sts.windows.net/contoso/"}} =
               SamlEntityId.new("https://sts.windows.net/contoso/")
    end

    test "accepts HTTP URL as entity ID" do
      assert {:ok, %SamlEntityId{value: "http://idp.example.com/saml"}} =
               SamlEntityId.new("http://idp.example.com/saml")
    end

    test "accepts URN as entity ID" do
      assert {:ok, %SamlEntityId{value: "urn:example:idp:entity"}} =
               SamlEntityId.new("urn:example:idp:entity")
    end

    test "rejects non-URL/non-URN values" do
      assert {:error, :invalid_entity_id} = SamlEntityId.new("invalid_value")
      assert {:error, :invalid_entity_id} = SamlEntityId.new("ftp://example.com")
    end

    test "rejects empty string" do
      assert {:error, :invalid_entity_id} = SamlEntityId.new("")
    end

    test "rejects nil" do
      assert {:error, :invalid_entity_id} = SamlEntityId.new(nil)
    end
  end

  describe "String.Chars implementation" do
    test "converts to string" do
      {:ok, entity_id} = SamlEntityId.new("https://sts.windows.net/contoso/")
      assert to_string(entity_id) == "https://sts.windows.net/contoso/"
    end
  end

  describe "Jason.Encoder implementation" do
    test "encodes as JSON string" do
      {:ok, entity_id} = SamlEntityId.new("https://sts.windows.net/contoso/")
      assert Jason.encode!(entity_id) == ~s("https://sts.windows.net/contoso/")
    end
  end
end
