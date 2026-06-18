defmodule Thalamus.Domain.ValueObjects.ClientIdTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.ValueObjects.ClientId

  describe "new/1" do
    test "creates valid client ID" do
      assert {:ok, %ClientId{value: "client_123"}} = ClientId.new("client_123")
      assert {:ok, %ClientId{value: "app-prod-001"}} = ClientId.new("app-prod-001")
    end

    test "returns error for empty string" do
      assert {:error, :invalid_client_id} = ClientId.new("")
    end

    test "returns error for too short" do
      assert {:error, :client_id_too_short} = ClientId.new("ab")
    end

    test "returns error for too long" do
      long_id = String.duplicate("a", 101)
      assert {:error, :client_id_too_long} = ClientId.new(long_id)
    end

    test "returns error for invalid characters" do
      assert {:error, :invalid_client_id_format} = ClientId.new("client@123")
      assert {:error, :invalid_client_id_format} = ClientId.new("client 123")
    end

    test "returns error for non-string" do
      assert {:error, :invalid_client_id} = ClientId.new(nil)
      assert {:error, :invalid_client_id} = ClientId.new(123)
    end
  end

  describe "generate/0" do
    test "generates unique client ID with prefix" do
      {:ok, client_id} = ClientId.generate()
      assert String.starts_with?(client_id.value, "client_")
      assert String.length(client_id.value) > 7
    end

    test "generates different IDs on each call" do
      {:ok, id1} = ClientId.generate()
      {:ok, id2} = ClientId.generate()
      assert id1.value != id2.value
    end
  end

  describe "to_string/1" do
    test "converts to string" do
      {:ok, client_id} = ClientId.new("client_123")
      assert ClientId.to_string(client_id) == "client_123"
    end
  end

  describe "from_string/1" do
    test "creates from valid string" do
      assert {:ok, %ClientId{value: "client_123"}} = ClientId.from_string("client_123")
    end

    test "returns error for invalid string" do
      assert {:error, _} = ClientId.from_string("")
    end
  end

  describe "String.Chars protocol" do
    test "implements to_string" do
      {:ok, client_id} = ClientId.new("client_123")
      assert to_string(client_id) == "client_123"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes to JSON" do
      {:ok, client_id} = ClientId.new("client_123")
      assert {:ok, "\"client_123\""} = Jason.encode(client_id)
    end
  end
end
