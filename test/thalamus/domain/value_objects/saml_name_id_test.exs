defmodule Thalamus.Domain.ValueObjects.SamlNameIdTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.ValueObjects.SamlNameId

  describe "new/2 with :email format" do
    test "accepts valid email" do
      assert {:ok, %SamlNameId{value: "user@example.com", format: :email}} =
               SamlNameId.new("user@example.com", :email)
    end

    test "defaults to :email format" do
      assert {:ok, %SamlNameId{format: :email}} = SamlNameId.new("user@example.com")
    end

    test "rejects empty string" do
      assert {:error, :empty_name_id} = SamlNameId.new("", :email)
    end
  end

  describe "new/2 with :persistent format" do
    test "accepts persistent identifier" do
      assert {:ok, %SamlNameId{value: "abcdef123456", format: :persistent}} =
               SamlNameId.new("abcdef123456", :persistent)
    end
  end

  describe "new/2 with :transient format" do
    test "accepts transient identifier" do
      assert {:ok, %SamlNameId{value: "tmp_session_id", format: :transient}} =
               SamlNameId.new("tmp_session_id", :transient)
    end
  end

  describe "new/2 with invalid format" do
    test "rejects unknown format" do
      assert {:error, :invalid_name_id} = SamlNameId.new("user@example.com", :unknown)
      assert {:error, :invalid_name_id} = SamlNameId.new("user@example.com", nil)
    end
  end
end
