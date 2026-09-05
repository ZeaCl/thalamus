defmodule Thalamus.Infrastructure.Repositories.PostgreSQLUserIdentityRepositoryTest do
  use Thalamus.DataCase, async: false

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserIdentityRepository,
    PostgreSQLUserRepository
  }

  alias Thalamus.Domain.Entities.{User, UserIdentity}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash}

  setup do
    {:ok, user_id} = UserId.generate()
    {:ok, email} = Email.new("test_user_#{System.unique_integer([:positive])}@zea.cl")
    {:ok, password_hash} = PasswordHash.from_password("SecurePassword123!")

    {:ok, user} =
      User.new(%{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :active
      })

    {:ok, saved_user} = PostgreSQLUserRepository.save(user)
    raw_uuid = String.replace_prefix(saved_user.id.value, "user_", "")

    %{user: saved_user, raw_uuid: raw_uuid}
  end

  describe "save/1 and find_by_provider_and_uid/2" do
    test "saves and retrieves a user identity", %{raw_uuid: raw_uuid} do
      {:ok, identity} =
        UserIdentity.new(%{
          user_id: raw_uuid,
          provider: "google",
          provider_uid: "google_sub_12345",
          email: "user@gmail.com",
          metadata: %{"locale" => "es"}
        })

      assert {:ok, saved} = PostgreSQLUserIdentityRepository.save(identity)
      assert saved.id != nil
      assert saved.user_id == raw_uuid
      assert saved.provider == "google"
      assert saved.provider_uid == "google_sub_12345"
      assert saved.email == "user@gmail.com"
      assert saved.metadata["locale"] == "es"

      assert {:ok, fetched} =
               PostgreSQLUserIdentityRepository.find_by_provider_and_uid(
                 "google",
                 "google_sub_12345"
               )

      assert fetched.id == saved.id
      assert fetched.user_id == raw_uuid
    end

    test "returns :not_found when identity does not exist" do
      assert {:error, :not_found} =
               PostgreSQLUserIdentityRepository.find_by_provider_and_uid("google", "nonexistent")
    end

    test "enforces uniqueness on provider and provider_uid", %{raw_uuid: raw_uuid} do
      {:ok, identity1} =
        UserIdentity.new(%{
          user_id: raw_uuid,
          provider: "github",
          provider_uid: "github_123"
        })

      assert {:ok, _} = PostgreSQLUserIdentityRepository.save(identity1)

      {:ok, identity2} =
        UserIdentity.new(%{
          user_id: raw_uuid,
          provider: "github",
          provider_uid: "github_123"
        })

      assert {:error, changeset} = PostgreSQLUserIdentityRepository.save(identity2)
      assert changeset.errors[:provider] != nil or changeset.errors[:provider_uid] != nil
    end
  end

  describe "find_all_by_user_id/1 and find_by_user_and_provider/2" do
    test "retrieves all identities for a user", %{raw_uuid: raw_uuid} do
      {:ok, id1} =
        UserIdentity.new(%{
          user_id: raw_uuid,
          provider: "google",
          provider_uid: "google_1"
        })

      {:ok, id2} =
        UserIdentity.new(%{
          user_id: raw_uuid,
          provider: "github",
          provider_uid: "github_2"
        })

      {:ok, _} = PostgreSQLUserIdentityRepository.save(id1)
      {:ok, _} = PostgreSQLUserIdentityRepository.save(id2)

      assert {:ok, identities} = PostgreSQLUserIdentityRepository.find_all_by_user_id(raw_uuid)
      assert length(identities) == 2

      assert {:ok, google_id} =
               PostgreSQLUserIdentityRepository.find_by_user_and_provider(raw_uuid, "google")

      assert google_id.provider == "google"
    end
  end

  describe "delete/1" do
    test "deletes an existing identity", %{raw_uuid: raw_uuid} do
      {:ok, identity} =
        UserIdentity.new(%{
          user_id: raw_uuid,
          provider: "apple",
          provider_uid: "apple_sub_1"
        })

      {:ok, saved} = PostgreSQLUserIdentityRepository.save(identity)
      assert :ok = PostgreSQLUserIdentityRepository.delete(saved.id)

      assert {:error, :not_found} =
               PostgreSQLUserIdentityRepository.find_by_provider_and_uid("apple", "apple_sub_1")
    end
  end
end
