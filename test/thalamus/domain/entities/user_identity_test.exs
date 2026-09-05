defmodule Thalamus.Domain.Entities.UserIdentityTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.Entities.UserIdentity

  describe "new/1" do
    test "creates a valid UserIdentity for supported providers" do
      for provider <- ["google", "apple", "github"] do
        attrs = %{
          user_id: UUID.uuid4(),
          provider: provider,
          provider_uid: "uid_12345",
          email: "user@example.com",
          metadata: %{"foo" => "bar"}
        }

        assert {:ok, %UserIdentity{} = identity} = UserIdentity.new(attrs)
        assert identity.provider == provider
        assert identity.provider_uid == "uid_12345"
        assert identity.email == "user@example.com"
        assert identity.metadata == %{"foo" => "bar"}
      end
    end

    test "validates required fields" do
      assert {:error, :missing_user_id} =
               UserIdentity.new(%{provider: "google", provider_uid: "123"})

      assert {:error, :missing_provider} =
               UserIdentity.new(%{user_id: UUID.uuid4(), provider_uid: "123"})

      assert {:error, :missing_provider_uid} =
               UserIdentity.new(%{user_id: UUID.uuid4(), provider: "google"})
    end

    test "rejects unsupported providers" do
      assert {:error, {:invalid_provider, "facebook"}} =
               UserIdentity.new(%{
                 user_id: UUID.uuid4(),
                 provider: "facebook",
                 provider_uid: "123"
               })
    end

    test "normalizes email to lowercase" do
      attrs = %{
        user_id: UUID.uuid4(),
        provider: "google",
        provider_uid: "123",
        email: "CAPS@EXAMPLE.COM"
      }

      assert {:ok, identity} = UserIdentity.new(attrs)
      assert identity.email == "caps@example.com"
    end
  end

  describe "supported_providers/0 and valid_provider?/1" do
    test "returns supported providers" do
      assert UserIdentity.supported_providers() == ["google", "apple", "github"]
      assert UserIdentity.valid_provider?("google")
      assert UserIdentity.valid_provider?("apple")
      assert UserIdentity.valid_provider?("github")
      refute UserIdentity.valid_provider?("twitter")
      refute UserIdentity.valid_provider?(nil)
    end
  end
end
