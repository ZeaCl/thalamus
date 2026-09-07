defmodule Thalamus.Application.UseCases.AuthenticateUserViaSocialTest do
  use Thalamus.DataCase, async: false

  alias Thalamus.Application.UseCases.AuthenticateUserViaSocial

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLUserIdentityRepository
  }

  alias Thalamus.Domain.Entities.{User, UserIdentity}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash}

  setup do
    unique = System.unique_integer([:positive])
    {:ok, user_id} = UserId.generate()
    {:ok, email} = Email.new("existing_#{unique}@zea.cl")
    {:ok, password_hash} = PasswordHash.from_password("Password123!")

    {:ok, user} =
      User.new(%{
        id: user_id,
        email: email,
        name: "Existing User",
        password_hash: password_hash,
        status: :active,
        verified_at: DateTime.truncate(DateTime.utc_now(), :second)
      })

    {:ok, saved_user} = PostgreSQLUserRepository.save(user)
    raw_uuid = String.replace_prefix(saved_user.id.value, "user_", "")

    %{user: saved_user, raw_uuid: raw_uuid, unique: unique}
  end

  describe "execute/2" do
    test "authenticates existing identity", %{user: user, raw_uuid: raw_uuid} do
      {:ok, identity} =
        UserIdentity.new(%{
          user_id: raw_uuid,
          provider: "google",
          provider_uid: "sub_existing_123",
          email: user.email.value
        })

      {:ok, _} = PostgreSQLUserIdentityRepository.save(identity)

      profile = %{
        provider: "google",
        provider_uid: "sub_existing_123",
        email: user.email.value,
        email_verified: true,
        name: "Updated Google Name",
        avatar_url: "https://example.com/pic.jpg",
        raw: %{}
      }

      assert {:ok, resp} = AuthenticateUserViaSocial.execute(profile)
      assert resp.authenticated == true
      assert resp.user_id == user.id.value
      assert resp.email == user.email.value
    end

    test "links new identity to existing user when verified email matches", %{
      user: user,
      raw_uuid: raw_uuid
    } do
      profile = %{
        provider: "github",
        provider_uid: "gh_uid_999",
        email: user.email.value,
        email_verified: true,
        name: "Octocat",
        avatar_url: "https://avatars.com/octo.png",
        raw: %{"login" => "octocat"}
      }

      assert {:ok, resp} = AuthenticateUserViaSocial.execute(profile)
      assert resp.authenticated == true
      assert resp.user_id == user.id.value

      # Verify identity was saved in DB
      assert {:ok, identity} =
               PostgreSQLUserIdentityRepository.find_by_provider_and_uid("github", "gh_uid_999")

      assert identity.user_id == raw_uuid
      assert identity.email == user.email.value
    end

    test "JIT provisions a brand new user when neither identity nor email exist", %{
      unique: unique
    } do
      new_email = "jit_user_#{unique}@zea.cl"

      profile = %{
        provider: "apple",
        provider_uid: "apple_new_user_sub",
        email: new_email,
        email_verified: true,
        name: "Steve Wozniak",
        avatar_url: nil,
        raw: %{}
      }

      assert {:ok, resp} = AuthenticateUserViaSocial.execute(profile)
      assert resp.authenticated == true
      assert resp.email == new_email
      assert resp.name == "Steve Wozniak"

      # Verify user was created in DB and is active
      {:ok, email_vo} = Email.new(new_email)
      assert {:ok, db_user} = PostgreSQLUserRepository.find_by_email(email_vo)
      assert db_user.status == :active
      assert db_user.name == "Steve Wozniak"
      assert db_user.verified_at != nil

      raw_user_uuid = String.replace_prefix(db_user.id.value, "user_", "")

      assert {:ok, identity} =
               PostgreSQLUserIdentityRepository.find_by_provider_and_uid(
                 "apple",
                 "apple_new_user_sub"
               )

      assert identity.user_id == raw_user_uuid
    end

    test "rejects authentication if social email is not verified" do
      profile = %{
        provider: "google",
        provider_uid: "unverified_sub",
        email: "unverified@example.com",
        email_verified: false,
        name: "Unverified",
        avatar_url: nil,
        raw: %{}
      }

      assert {:error, :unverified_social_email} = AuthenticateUserViaSocial.execute(profile)
    end

    test "rejects authentication if user account is suspended", %{user: user, raw_uuid: raw_uuid} do
      # Suspend user
      suspended_user = %{user | status: :suspended}
      {:ok, _} = PostgreSQLUserRepository.save(suspended_user)

      {:ok, identity} =
        UserIdentity.new(%{
          user_id: raw_uuid,
          provider: "google",
          provider_uid: "sub_suspended_1",
          email: user.email.value
        })

      {:ok, _} = PostgreSQLUserIdentityRepository.save(identity)

      profile = %{
        provider: "google",
        provider_uid: "sub_suspended_1",
        email: user.email.value,
        email_verified: true,
        name: user.name,
        avatar_url: nil,
        raw: %{}
      }

      assert {:error, :account_suspended} = AuthenticateUserViaSocial.execute(profile)
    end

    test "authenticates existing Apple identity on recurring login when email is nil", %{
      user: user,
      raw_uuid: raw_uuid
    } do
      {:ok, identity} =
        UserIdentity.new(%{
          user_id: raw_uuid,
          provider: "apple",
          provider_uid: "apple_recurring_sub_123",
          email: user.email.value
        })

      {:ok, _} = PostgreSQLUserIdentityRepository.save(identity)

      # Apple omits email and sets email_verified to false/nil on recurring logins
      profile = %{
        provider: "apple",
        provider_uid: "apple_recurring_sub_123",
        email: nil,
        email_verified: false,
        name: nil,
        avatar_url: nil,
        raw: %{}
      }

      assert {:ok, resp} = AuthenticateUserViaSocial.execute(profile)
      assert resp.authenticated == true
      assert resp.user_id == user.id.value
      assert resp.email == user.email.value
    end

    test "rejects new identity creation when email is nil or missing" do
      profile = %{
        provider: "apple",
        provider_uid: "apple_new_unknown_sub",
        email: nil,
        email_verified: false,
        name: nil,
        avatar_url: nil,
        raw: %{}
      }

      assert {:error, :missing_social_email} = AuthenticateUserViaSocial.execute(profile)
    end

    test "strips sensitive tokens from identity metadata upon linking", %{
      user: user,
      raw_uuid: raw_uuid
    } do
      profile = %{
        provider: "github",
        provider_uid: "gh_uid_sensitive_tokens",
        email: user.email.value,
        email_verified: true,
        name: "Security Conscious",
        avatar_url: nil,
        raw: %{
          "login" => "secuser",
          "access_token" => "gho_secret_access_token_123",
          "refresh_token" => "ghr_secret_refresh_token_123",
          "id_token" => "ey.secret_id_token.sig"
        }
      }

      assert {:ok, _resp} = AuthenticateUserViaSocial.execute(profile)

      assert {:ok, identity} =
               PostgreSQLUserIdentityRepository.find_by_provider_and_uid(
                 "github",
                 "gh_uid_sensitive_tokens"
               )

      assert identity.user_id == raw_uuid
      assert identity.metadata["login"] == "secuser"
      refute Map.has_key?(identity.metadata, "access_token")
      refute Map.has_key?(identity.metadata, "refresh_token")
      refute Map.has_key?(identity.metadata, "id_token")
    end
  end
end
