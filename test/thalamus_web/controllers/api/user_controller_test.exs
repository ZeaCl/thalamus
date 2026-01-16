defmodule ThalamusWeb.API.UserControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.AccessToken

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLTokenRepository
  }

  setup do
    # Create admin user with access token
    {:ok, admin} = User.register("admin@test.com", "AdminPass123!")
    {:ok, admin} = User.verify_email(admin)
    {:ok, admin} = PostgreSQLUserRepository.save(admin)

    # Generate access token
    {:ok, access_token} =
      AccessToken.generate(
        admin.id,
        Thalamus.Domain.ValueObjects.ClientId.generate(),
        [:read, :write, :admin],
        3600
      )

    token_data = %{
      token: access_token.token,
      type: :access_token,
      user_id: admin.id,
      scope: [:read, :write, :admin],
      expires_at: access_token.expires_at
    }

    :ok = PostgreSQLTokenRepository.store(token_data)

    {:ok, %{admin: admin, access_token: access_token.token}}
  end

  describe "GET /api/users" do
    test "lists all users", %{conn: conn, access_token: token} do
      # Create additional users
      {:ok, user1} = User.register("user1@test.com", "Pass123!")
      {:ok, user1} = User.verify_email(user1)
      {:ok, _} = PostgreSQLUserRepository.save(user1)

      {:ok, user2} = User.register("user2@test.com", "Pass123!")
      {:ok, _} = PostgreSQLUserRepository.save(user2)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users")

      assert %{
               "data" => users
             } = json_response(conn, 200)

      assert is_list(users)
      # At least admin + 2 new users
      assert length(users) >= 3
    end

    test "filters users by status", %{conn: conn, access_token: token} do
      # Create verified user
      {:ok, verified_user} = User.register("verified@test.com", "Pass123!")
      {:ok, verified_user} = User.verify_email(verified_user)
      {:ok, _} = PostgreSQLUserRepository.save(verified_user)

      # Create unverified user
      {:ok, unverified_user} = User.register("unverified@test.com", "Pass123!")
      {:ok, _} = PostgreSQLUserRepository.save(unverified_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users?status=active")

      assert %{
               "data" => users
             } = json_response(conn, 200)

      # All returned users should be active
      Enum.each(users, fn user ->
        assert user["status"] == "active"
      end)
    end

    test "filters users by verified status", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users?verified=true")

      assert %{
               "data" => users
             } = json_response(conn, 200)

      Enum.each(users, fn user ->
        assert user["verified"] == true
      end)
    end

    test "paginates results", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users?limit=2&offset=0")

      assert %{
               "data" => users,
               "meta" => meta
             } = json_response(conn, 200)

      assert length(users) <= 2
      assert is_map(meta)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/users")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/users" do
    test "creates new user with valid data", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/users", %{
          email: "newuser@test.com",
          password: "NewPass123!"
        })

      assert %{
               "data" => %{
                 "id" => id,
                 "email" => "newuser@test.com",
                 "status" => status,
                 "verified" => false
               }
             } = json_response(conn, 201)

      assert is_binary(id)
      assert status in ["pending_verification", "active"]
    end

    test "returns error with existing email", %{conn: conn, access_token: token} do
      # Create user first
      {:ok, user} = User.register("existing@test.com", "Pass123!")
      {:ok, _} = PostgreSQLUserRepository.save(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/users", %{
          email: "existing@test.com",
          password: "AnotherPass123!"
        })

      assert %{
               "error" => _
             } = json_response(conn, 409)
    end

    test "returns error with invalid email", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/users", %{
          email: "not-an-email",
          password: "Pass123!"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with weak password", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/users", %{
          email: "user@test.com",
          password: "weak"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "requires authentication", %{conn: conn} do
      conn =
        post(conn, ~p"/api/users", %{
          email: "user@test.com",
          password: "Pass123!"
        })

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/users/:id" do
    test "returns user by id", %{conn: conn, admin: admin, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{admin.id}")

      assert %{
               "data" => %{
                 "id" => id,
                 "email" => "admin@test.com",
                 "verified" => true
               }
             } = json_response(conn, 200)

      assert id == to_string(admin.id)
    end

    test "returns 404 for non-existent user", %{conn: conn, access_token: token} do
      fake_id = Thalamus.Domain.ValueObjects.UserId.generate!()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{fake_id}")

      assert %{
               "error" => _
             } = json_response(conn, 404)
    end

    test "returns 400 for invalid id format", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/invalid-id")

      assert json_response(conn, 400)
    end

    test "requires authentication", %{conn: conn, admin: admin} do
      conn = get(conn, ~p"/api/users/#{admin.id}")

      assert json_response(conn, 401)
    end
  end

  describe "PATCH /api/users/:id" do
    test "updates user status", %{conn: conn, access_token: token} do
      {:ok, user} = User.register("update@test.com", "Pass123!")
      {:ok, user} = PostgreSQLUserRepository.save(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/users/#{user.id}", %{
          status: "suspended"
        })

      assert %{
               "data" => %{
                 "id" => _,
                 "status" => "suspended"
               }
             } = json_response(conn, 200)
    end

    test "returns 404 for non-existent user", %{conn: conn, access_token: token} do
      fake_id = Thalamus.Domain.ValueObjects.UserId.generate!()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/users/#{fake_id}", %{
          status: "suspended"
        })

      assert json_response(conn, 404)
    end

    test "requires authentication", %{conn: conn, admin: admin} do
      conn =
        patch(conn, ~p"/api/users/#{admin.id}", %{
          status: "suspended"
        })

      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/users/:id" do
    test "deletes user", %{conn: conn, access_token: token} do
      {:ok, user} = User.register("delete@test.com", "Pass123!")
      {:ok, user} = PostgreSQLUserRepository.save(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/users/#{user.id}")

      assert response(conn, 204)

      # Verify user is deleted
      assert {:error, :not_found} = PostgreSQLUserRepository.find_by_id(user.id)
    end

    test "returns 404 for non-existent user", %{conn: conn, access_token: token} do
      fake_id = Thalamus.Domain.ValueObjects.UserId.generate!()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/users/#{fake_id}")

      assert json_response(conn, 404)
    end

    test "requires authentication", %{conn: conn, admin: admin} do
      conn = delete(conn, ~p"/api/users/#{admin.id}")

      assert json_response(conn, 401)
    end
  end
end
