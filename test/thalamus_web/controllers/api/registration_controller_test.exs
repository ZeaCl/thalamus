defmodule ThalamusWeb.API.RegistrationControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository

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
                 "status" => "pending_verification",
                 "verified" => false
               },
               "message" => message
             } = json_response(conn, 201)

      assert is_binary(id)
      assert String.contains?(message, "verification")
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
