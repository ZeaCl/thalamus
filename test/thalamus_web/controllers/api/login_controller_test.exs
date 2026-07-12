defmodule ThalamusWeb.API.LoginControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{UserDomainRoleSchema, UserSchema}

  @valid_email "test@example.com"
  @valid_password "SecurePass123!@#"
  @org_id "ea7b11ea-852c-44e5-aee1-a761ec76eaea"

  describe "POST /api/public/login" do
    setup do
      {:ok, user} = create_active_user()
      %{user: user}
    end

    test "successful login returns JWT with domain_roles", %{conn: conn, user: user} do
      # Grant a domain role so domain_roles claim is populated
      create_domain_role(user.id, "funds", "gp_admin", ["read", "write"])

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

      # Decode JWT and verify domain_roles claim
      [_header, payload_b64, _sig] = String.split(access_token, ".")
      {:ok, payload_json} = Base.url_decode64(payload_b64, padding: false)
      {:ok, payload} = Jason.decode(payload_json)

      assert is_list(payload["domain_roles"])
      assert length(payload["domain_roles"]) > 0
      assert payload["authz_source"] == "domain_roles"

      domain_role = List.first(payload["domain_roles"])
      assert domain_role["domain"] == "funds"
      assert domain_role["role"] == "gp_admin"
      assert domain_role["scopes"] == ["read", "write"]
    end

    test "successful login without domain roles returns JWT with empty domain_roles array", %{
      conn: conn
    } do
      conn =
        post(conn, ~p"/api/public/login", %{
          email: @valid_email,
          password: @valid_password
        })

      assert %{
               "access_token" => access_token,
               "user" => _user_data
             } = json_response(conn, 200)

      # Decode JWT
      [_header, payload_b64, _sig] = String.split(access_token, ".")
      {:ok, payload_json} = Base.url_decode64(payload_b64, padding: false)
      {:ok, payload} = Jason.decode(payload_json)

      # domain_roles is always present (empty array when user has no roles)
      assert payload["domain_roles"] == []
      assert payload["authz_source"] == "domain_roles"
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

    test "suspended user returns 401", %{conn: conn} do
      {:ok, _} =
        Repo.insert(
          UserSchema.create_changeset(%{
            email: "suspended@test.com",
            name: "Suspended",
            password_hash: Bcrypt.hash_pwd_salt("Password123!"),
            status: :suspended
          })
        )

      conn =
        post(conn, ~p"/api/public/login", %{
          email: "suspended@test.com",
          password: "Password123!"
        })

      assert %{
               "error" => "account_suspended",
               "error_description" => "Account has been suspended"
             } = json_response(conn, 401)
    end

    test "deactivated user returns 401", %{conn: conn} do
      {:ok, _} =
        Repo.insert(
          UserSchema.create_changeset(%{
            email: "deactivated@test.com",
            name: "Deactivated",
            password_hash: Bcrypt.hash_pwd_salt("Password123!"),
            status: :deactivated
          })
        )

      conn =
        post(conn, ~p"/api/public/login", %{
          email: "deactivated@test.com",
          password: "Password123!"
        })

      assert %{
               "error" => "account_suspended",
               "error_description" => "Account has been suspended"
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
    Repo.insert(
      UserSchema.create_changeset(%{
        email: @valid_email,
        name: "Test User",
        password_hash: Bcrypt.hash_pwd_salt(@valid_password),
        status: :active,
        verified_at: DateTime.truncate(DateTime.utc_now(), :second)
      })
    )
  end

  defp create_domain_role(user_id, domain, role, scopes) do
    Repo.insert(%UserDomainRoleSchema{
      user_id: user_id,
      organization_id: @org_id,
      domain: domain,
      role: role,
      scopes: scopes
    })
  end
end
