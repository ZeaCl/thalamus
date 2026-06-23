defmodule ThalamusWeb.API.LoginControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

  @valid_email "test@example.com"
  @valid_password "SecurePass123!@#"

  describe "POST /api/public/login" do
    setup do
      create_active_user()
      %{}
    end

    test "successful login returns tokens and user info", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: @valid_email,
          password: @valid_password
        })

      assert %{
               "access_token" => access_token,
               "token_type" => "Bearer",
               "expires_in" => 3600,
               "user" => user_data
             } = json_response(conn, 200)

      assert is_binary(access_token)
      assert String.starts_with?(access_token, "eyJ")
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
               "error_description" => "Invalid email or password"
             } = json_response(conn, 401)
    end

    test "non-existent user returns 401", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: "noone@example.com",
          password: @valid_password
        })

      assert %{"error" => "invalid_credentials"} = json_response(conn, 401)
    end

    test "missing email returns 400", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          password: @valid_password
        })

      assert %{"error" => "missing_parameter"} = json_response(conn, 400)
    end

    test "missing password returns 400", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: @valid_email
        })

      assert %{"error" => "missing_parameter"} = json_response(conn, 400)
    end

    test "empty body returns 400", %{conn: conn} do
      conn = post(conn, ~p"/api/public/login", %{})

      assert %{"error" => "missing_parameter"} = json_response(conn, 400)
    end

    test "inactive user returns 401", %{conn: conn} do
      {:ok, _} =
        Repo.insert(UserSchema.create_changeset(%{
          email: "inactive@test.com",
          name: "Inactive",
          password_hash: Bcrypt.hash_pwd_salt("Password123!"),
          status: :deactivated
        }))

      conn =
        post(conn, ~p"/api/public/login", %{
          email: "inactive@test.com",
          password: "Password123!"
        })

      assert %{
               "error" => "account_inactive",
               "error_description" => "Account is not active"
             } = json_response(conn, 401)
    end

    test "email is case-insensitive", %{conn: conn} do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: "TEST@example.com",
          password: @valid_password
        })

      assert json_response(conn, 200)
    end
  end

  defp create_active_user do
    {:ok, _} =
      Repo.insert(UserSchema.create_changeset(%{
        email: @valid_email,
        name: "Test User",
        password_hash: Bcrypt.hash_pwd_salt(@valid_password),
        status: :active,
        verified_at: DateTime.truncate(DateTime.utc_now(), :second)
      }))
  end
end
