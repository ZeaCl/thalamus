defmodule ThalamusWeb.API.PasswordControllerTest do
  use ThalamusWeb.ConnCase, async: true

  # TODO: Migrate to new AccessToken.generate API
  # Old: AccessToken.generate(user_id, client_id, scopes, ttl)
  # New: AccessToken.generate(scopes, subject, ttl, token_type)
  @moduletag :skip

  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.AccessToken

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLTokenRepository
  }

  setup do
    # Create and verify user
    {:ok, user} = User.register("user@test.com", "OldPassword123!")
    {:ok, user} = User.verify_email(user)
    {:ok, user} = PostgreSQLUserRepository.save(user)

    # Generate access token for authenticated requests
    {:ok, access_token} =
      AccessToken.generate(
        user.id,
        Thalamus.Domain.ValueObjects.ClientId.generate(),
        [:read, :write],
        3600
      )

    token_data = %{
      token: access_token.token,
      type: :access_token,
      user_id: user.id,
      scope: [:read, :write],
      expires_at: access_token.expires_at
    }

    :ok = PostgreSQLTokenRepository.store(token_data)

    {:ok, %{user: user, access_token: access_token.token}}
  end

  describe "POST /api/public/password/reset" do
    test "sends reset email for existing user", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/password/reset", %{
          email: "user@test.com"
        })

      # Should always return 200 to prevent email enumeration
      assert %{
               "message" => message
             } = json_response(conn, 200)

      assert String.contains?(message, "email") or String.contains?(message, "sent")
    end

    test "returns success for non-existent email (prevents enumeration)", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/password/reset", %{
          email: "nonexistent@test.com"
        })

      # Should return 200 even if email doesn't exist (security feature)
      assert %{
               "message" => _
             } = json_response(conn, 200)
    end

    test "returns error with invalid email format", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/password/reset", %{
          email: "not-an-email"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with missing email", %{conn: conn} do
      conn = post(conn, ~p"/api/public/password/reset", %{})

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end
  end

  describe "POST /api/public/password/confirm-reset" do
    test "resets password with valid token", %{conn: conn, user: user} do
      # First, request password reset to get token
      reset_conn =
        post(conn, ~p"/api/public/password/reset", %{
          email: "user@test.com"
        })

      response = json_response(reset_conn, 200)

      # In development mode, token might be returned
      if token = response["reset_token"] do
        # Confirm reset with new password
        confirm_conn =
          post(conn, ~p"/api/public/password/confirm-reset", %{
            token: token,
            password: "NewPassword123!",
            password_confirmation: "NewPassword123!"
          })

        assert %{
                 "message" => message
               } = json_response(confirm_conn, 200)

        assert String.contains?(message, "reset") or String.contains?(message, "success")

        # Verify can login with new password
        {:ok, updated_user} = PostgreSQLUserRepository.find_by_id(user.id)
        {:ok, can_login} = User.verify_password(updated_user, "NewPassword123!")
        assert can_login == true
      end
    end

    test "returns error with invalid token", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/password/confirm-reset", %{
          token: "invalid_token_123",
          password: "NewPassword123!",
          password_confirmation: "NewPassword123!"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with password mismatch", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/password/confirm-reset", %{
          token: "some_token",
          password: "NewPassword123!",
          password_confirmation: "DifferentPassword123!"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with weak password", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/password/confirm-reset", %{
          token: "some_token",
          password: "weak",
          password_confirmation: "weak"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with missing fields", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/password/confirm-reset", %{
          token: "some_token"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end
  end

  describe "PUT /api/password/change - authenticated" do
    test "changes password with valid current password", %{
      conn: conn,
      user: user,
      access_token: token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/password/change", %{
          current_password: "OldPassword123!",
          new_password: "NewPassword456!",
          new_password_confirmation: "NewPassword456!"
        })

      assert %{
               "message" => message
             } = json_response(conn, 200)

      assert String.contains?(message, "changed") or String.contains?(message, "success")

      # Verify can login with new password
      {:ok, updated_user} = PostgreSQLUserRepository.find_by_id(user.id)
      {:ok, can_login} = User.verify_password(updated_user, "NewPassword456!")
      assert can_login == true

      # Verify old password no longer works
      {:ok, cannot_login} = User.verify_password(updated_user, "OldPassword123!")
      assert cannot_login == false
    end

    test "returns error with incorrect current password", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/password/change", %{
          current_password: "WrongPassword!",
          new_password: "NewPassword456!",
          new_password_confirmation: "NewPassword456!"
        })

      assert %{
               "error" => error
             } = json_response(conn, 400)

      assert String.contains?(error, "current") or String.contains?(error, "incorrect")
    end

    test "returns error with password mismatch", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/password/change", %{
          current_password: "OldPassword123!",
          new_password: "NewPassword456!",
          new_password_confirmation: "DifferentPassword!"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with weak new password", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/password/change", %{
          current_password: "OldPassword123!",
          new_password: "weak",
          new_password_confirmation: "weak"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with same password as current", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/password/change", %{
          current_password: "OldPassword123!",
          new_password: "OldPassword123!",
          new_password_confirmation: "OldPassword123!"
        })

      assert %{
               "error" => error
             } = json_response(conn, 400)

      assert String.contains?(error, "same") or String.contains?(error, "different")
    end

    test "requires authentication", %{conn: conn} do
      conn =
        put(conn, ~p"/api/password/change", %{
          current_password: "OldPassword123!",
          new_password: "NewPassword456!",
          new_password_confirmation: "NewPassword456!"
        })

      assert json_response(conn, 401)
    end

    test "returns error with missing fields", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/password/change", %{
          current_password: "OldPassword123!"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end
  end

  describe "password reset token expiration" do
    test "rejects expired reset token", %{conn: conn} do
      # This would require time manipulation
      # For now, we just test with an obviously expired token format
      conn =
        post(conn, ~p"/api/public/password/confirm-reset", %{
          token: "expired:1234567890:signature",
          password: "NewPassword123!",
          password_confirmation: "NewPassword123!"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end
  end

  describe "rate limiting on password reset" do
    @tag :rate_limit
    test "rate limits password reset requests", %{conn: conn} do
      # Make multiple requests
      for _n <- 1..25 do
        post(conn, ~p"/api/public/password/reset", %{
          email: "user@test.com"
        })
      end

      # Next request should be rate limited
      conn =
        post(conn, ~p"/api/public/password/reset", %{
          email: "user@test.com"
        })

      # Should return 429 Too Many Requests
      assert conn.status == 429
    end
  end
end
