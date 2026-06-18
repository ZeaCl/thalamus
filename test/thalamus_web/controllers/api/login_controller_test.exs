defmodule ThalamusWeb.API.LoginControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Entities.User
  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository

  @valid_email "test@example.com"
  @valid_password "SecurePass123!@#"

  describe "POST /api/public/login" do
    setup do
      # Create a test user
      {:ok, user} = User.register(@valid_email, @valid_password)
      # Verify email so user can login (changes status to :active)
      {:ok, verified_user} = User.verify_email(user)
      # Save the verified user
      {:ok, saved_user} = PostgreSQLUserRepository.save(verified_user)

      # Debug: verify the user was saved correctly
      IO.puts("Setup: saved_user status = #{saved_user.status}")
      IO.puts("Setup: saved_user verified_at = #{inspect(saved_user.verified_at)}")

      %{user: saved_user}
    end

    test "successful login returns tokens and user info", %{conn: conn, user: _user} do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: @valid_email,
          password: @valid_password
        })

      assert %{
               "access_token" => access_token,
               "token_type" => "Bearer",
               "expires_in" => 3600,
               "refresh_token" => refresh_token,
               "user" => user_data,
               "organization" => _org_data
             } = json_response(conn, 200)

      # Verify tokens have correct prefixes
      assert String.starts_with?(access_token, "at_")
      assert String.starts_with?(refresh_token, "rt_")

      # Verify user data
      assert user_data["email"] == @valid_email
      assert user_data["verified"] == true
      assert is_binary(user_data["id"])
    end

    test "invalid credentials return 401", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: @valid_email,
          password: "WrongPassword123!"
        })

      assert %{
               "error" => "invalid_credentials",
               "error_description" => _
             } = json_response(conn, 401)
    end

    test "non-existent user returns 401", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: "nonexistent@example.com",
          password: @valid_password
        })

      assert %{
               "error" => "invalid_credentials",
               "error_description" => _
             } = json_response(conn, 401)
    end

    test "missing email returns 400", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          password: @valid_password
        })

      assert %{
               "error" => "missing_parameter",
               "error_description" => error_desc
             } = json_response(conn, 400)

      assert error_desc =~ "email"
    end

    test "missing password returns 400", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: @valid_email
        })

      assert %{
               "error" => "missing_parameter",
               "error_description" => error_desc
             } = json_response(conn, 400)

      assert error_desc =~ "password"
    end

    test "unverified user returns 401", %{conn: conn} do
      # Create an unverified user
      {:ok, unverified_user} = User.register("unverified@example.com", @valid_password)
      PostgreSQLUserRepository.save(unverified_user)

      conn =
        post(conn, ~p"/api/public/login", %{
          email: "unverified@example.com",
          password: @valid_password
        })

      assert %{
               "error" => "account_not_verified",
               "error_description" => _
             } = json_response(conn, 401)
    end

    test "suspended user returns 401", %{conn: conn, user: user} do
      # Suspend the user
      {:ok, suspended_user} = User.suspend(user)
      PostgreSQLUserRepository.save(suspended_user)

      conn =
        post(conn, ~p"/api/public/login", %{
          email: @valid_email,
          password: @valid_password
        })

      assert %{
               "error" => "account_suspended",
               "error_description" => _
             } = json_response(conn, 401)
    end

    test "locked account returns 401", %{conn: conn, user: user} do
      # Lock the account by recording 5 failed attempts
      locked_user =
        Enum.reduce(1..5, user, fn _, acc ->
          {:ok, updated} = User.record_failed_login(acc)
          updated
        end)

      PostgreSQLUserRepository.save(locked_user)

      conn =
        post(conn, ~p"/api/public/login", %{
          email: @valid_email,
          password: @valid_password
        })

      assert %{
               "error" => "account_locked",
               "error_description" => _
             } = json_response(conn, 401)
    end

    test "successful login updates last_login_at", %{conn: conn, user: user} do
      initial_last_login = user.last_login_at

      post(conn, ~p"/api/public/login", %{
        email: @valid_email,
        password: @valid_password
      })

      # Fetch user again to check last_login_at
      {:ok, updated_user} = PostgreSQLUserRepository.find_by_id(user.id)
      assert updated_user.last_login_at != initial_last_login
      assert updated_user.last_login_at != nil
    end

    test "failed login increments failed_login_attempts", %{conn: conn, user: user} do
      initial_attempts = user.failed_login_attempts

      post(conn, ~p"/api/public/login", %{
        email: @valid_email,
        password: "WrongPassword"
      })

      # Fetch user again to check failed attempts
      {:ok, updated_user} = PostgreSQLUserRepository.find_by_id(user.id)
      assert updated_user.failed_login_attempts == initial_attempts + 1
    end

    test "organization is null when user has no organization", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: @valid_email,
          password: @valid_password
        })

      assert %{"organization" => nil} = json_response(conn, 200)
    end
  end
end
