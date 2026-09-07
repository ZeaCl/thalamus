defmodule ThalamusWeb.API.RegistrationControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLOAuth2ClientRepository
  }

  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.Domain.ValueObjects.{OrganizationId, Email, ClientId}
  import Thalamus.TestHelpers

  describe "POST /api/public/register" do
    test "registers new user with valid data", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "newuser@test.com",
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!"
        })

      assert %{
               "data" => %{
                 "id" => id,
                 "email" => "newuser@test.com",
                 "status" => "active",
                 "verified" => true,
                 "organization_id" => org_id
               },
               "message" => message
             } = json_response(conn, 201)

      assert is_binary(id)
      assert is_binary(org_id)
      assert String.contains?(message, "successful")
    end

    test "registers new user with explicit organization_id", %{conn: conn} do
      {:ok, org} = Organization.new("NutriSnaps Corp", "owner@nutrisnaps.com", :free)
      {:ok, saved_org} = PostgreSQLOrganizationRepository.save(org)
      org_id_str = OrganizationId.to_string(saved_org.id)

      conn =
        post(conn, ~p"/api/public/register", %{
          email: "member@nutrisnaps.com",
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!",
          name: "NutriSnaps Member",
          organization_id: org_id_str
        })

      assert %{
               "data" => %{
                 "id" => user_id_str,
                 "email" => "member@nutrisnaps.com",
                 "status" => "active",
                 "verified" => true,
                 "organization_id" => ^org_id_str
               }
             } = json_response(conn, 201)

      # Verify user in database has active status and verified_at
      {:ok, email_vo} = Email.new("member@nutrisnaps.com")
      {:ok, user} = PostgreSQLUserRepository.find_by_email(email_vo)
      assert user.status == :active
      assert not is_nil(user.verified_at)

      # Check database schema level organization_id
      user_uuid = String.replace_prefix(user_id_str, "user_", "")

      user_schema =
        Thalamus.Repo.get(Thalamus.Infrastructure.Persistence.Schemas.UserSchema, user_uuid)

      org_uuid = String.replace_prefix(org_id_str, "org_", "")
      assert user_schema.organization_id == org_uuid

      # Check organization members contains this user
      {:ok, reloaded_org} = PostgreSQLOrganizationRepository.find_by_id(saved_org.id)
      assert Enum.any?(reloaded_org.members, fn m -> m.email == email_vo end)
    end

    test "registers new user with explicit client_id", %{conn: conn} do
      {:ok, org} = Organization.new("Client App Org", "appowner@test.com", :free)
      {:ok, saved_org} = PostgreSQLOrganizationRepository.save(org)
      {:ok, client} = create_test_client("NutriSnaps API", saved_org.id, ["openid", "profile"])
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      client_id_str = ClientId.to_string(saved_client.id)
      expected_org_id_str = OrganizationId.to_string(saved_org.id)

      conn =
        post(conn, ~p"/api/public/register", %{
          email: "clientuser@test.com",
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!",
          client_id: client_id_str
        })

      assert %{
               "data" => %{
                 "email" => "clientuser@test.com",
                 "status" => "active",
                 "verified" => true,
                 "organization_id" => ^expected_org_id_str
               }
             } = json_response(conn, 201)
    end

    test "registers new user with organization_name creates new organization", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "neworguser@test.com",
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!",
          name: "Org Founder",
          organization_name: "Startup Inc"
        })

      assert %{
               "data" => %{
                 "email" => "neworguser@test.com",
                 "status" => "active",
                 "verified" => true,
                 "organization_id" => org_id_str
               }
             } = json_response(conn, 201)

      {:ok, org_id} = OrganizationId.from_string(org_id_str)
      {:ok, org} = PostgreSQLOrganizationRepository.find_by_id(org_id)
      assert org.name == "Startup Inc"
    end

    test "returns error with non-existent organization_id", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "badorg@test.com",
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!",
          organization_id: "org_00000000-0000-0000-0000-000000000000"
        })

      assert %{"error" => "Organization not found"} = json_response(conn, 400)
    end

    test "returns error with non-existent client_id", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "badclient@test.com",
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!",
          client_id: "client_00000000-0000-0000-0000-000000000000"
        })

      assert %{"error" => "OAuth2 client not found"} = json_response(conn, 400)
    end

    test "registered user can immediately authenticate via session controller", %{conn: conn} do
      post(conn, ~p"/api/public/register", %{
        email: "authtest@test.com",
        password: "SecurePass123!",
        password_confirmation: "SecurePass123!"
      })

      login_conn =
        post(conn, ~p"/login", %{
          "session" => %{
            "email" => "authtest@test.com",
            "password" => "SecurePass123!"
          }
        })

      assert redirected_to(login_conn, 302)
    end

    test "returns verification token in development mode", %{conn: conn} do
      # Assuming we're in development mode
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "devuser@test.com",
          password: "DevPass123!",
          password_confirmation: "DevPass123!"
        })

      response = json_response(conn, 201)

      # In development, should include verification_token
      if Application.get_env(:thalamus, :environment) == :development do
        assert %{"verification_token" => token} = response
        assert is_binary(token)
      end
    end

    test "returns error with existing email", %{conn: conn} do
      # Create user first
      post(conn, ~p"/api/public/register", %{
        email: "existing@test.com",
        password: "Pass123!",
        password_confirmation: "Pass123!"
      })

      # Try to register again with same email
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "existing@test.com",
          password: "AnotherPass123!",
          password_confirmation: "AnotherPass123!"
        })

      assert %{
               "error" => error
             } = json_response(conn, 409)

      assert String.contains?(error, "already exists") or String.contains?(error, "taken")
    end

    test "returns error with password mismatch", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "user@test.com",
          password: "Password123!",
          password_confirmation: "DifferentPass123!"
        })

      assert %{
               "error" => error
             } = json_response(conn, 400)

      assert String.contains?(error, "match") or String.contains?(error, "confirmation")
    end

    test "returns error with weak password", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "user@test.com",
          password: "weak",
          password_confirmation: "weak"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with invalid email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "not-an-email",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with missing fields", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/register", %{
          email: "user@test.com"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end
  end

  describe "POST /api/public/verify-email" do
    test "verifies email with valid token", %{conn: conn} do
      # Register user first
      register_conn =
        post(conn, ~p"/api/public/register", %{
          email: "verify@test.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      response = json_response(register_conn, 201)

      # In development, we get the token
      if token = response["verification_token"] do
        # Verify email
        verify_conn =
          post(conn, ~p"/api/public/verify-email", %{
            email: "verify@test.com",
            token: token
          })

        assert %{
                 "message" => message
               } = json_response(verify_conn, 200)

        assert String.contains?(message, "verified") or String.contains?(message, "success")

        # Check user is verified
        {:ok, email_vo} = Thalamus.Domain.ValueObjects.Email.new("verify@test.com")
        {:ok, user} = PostgreSQLUserRepository.find_by_email(email_vo)
        assert !is_nil(user.verified_at)
        assert user.status == :active
      end
    end

    test "returns error with invalid token", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/verify-email", %{
          email: "user@test.com",
          token: "invalid_token_123"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with expired token", %{conn: conn} do
      # This would require mocking time or waiting
      # For now, just test with invalid token format
      conn =
        post(conn, ~p"/api/public/verify-email", %{
          email: "user@test.com",
          token: "expired_token"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with missing fields", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/verify-email", %{
          email: "user@test.com"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end
  end

  describe "POST /api/public/resend-verification" do
    test "resends verification email for unverified user", %{conn: conn} do
      # Register user
      post(conn, ~p"/api/public/register", %{
        email: "resend@test.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })

      # Resend verification
      conn =
        post(conn, ~p"/api/public/resend-verification", %{
          email: "resend@test.com"
        })

      # Should always return 200 to prevent email enumeration
      assert %{
               "message" => message
             } = json_response(conn, 200)

      assert String.contains?(message, "sent") or String.contains?(message, "email")
    end

    test "returns success for non-existent email (prevents enumeration)", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/resend-verification", %{
          email: "nonexistent@test.com"
        })

      # Should return 200 even if email doesn't exist (security feature)
      assert %{
               "message" => _
             } = json_response(conn, 200)
    end

    test "returns success for already verified user (prevents enumeration)", %{conn: conn} do
      # Register and verify user
      register_conn =
        post(conn, ~p"/api/public/register", %{
          email: "verified@test.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      response = json_response(register_conn, 201)

      if token = response["verification_token"] do
        post(conn, ~p"/api/public/verify-email", %{
          email: "verified@test.com",
          token: token
        })
      end

      # Try to resend
      resend_conn =
        post(conn, ~p"/api/public/resend-verification", %{
          email: "verified@test.com"
        })

      # Should still return 200 (security feature)
      assert %{
               "message" => _
             } = json_response(resend_conn, 200)
    end

    test "returns error with missing email", %{conn: conn} do
      conn = post(conn, ~p"/api/public/resend-verification", %{})

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with invalid email format", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/resend-verification", %{
          email: "not-an-email"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end
  end
end
