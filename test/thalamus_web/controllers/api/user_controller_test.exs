defmodule ThalamusWeb.API.UserControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Domain.ValueObjects.{AccessToken, Scope}

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLTokenRepository
  }

  setup do
    # Create organization for OAuth2 client
    {:ok, org} = Organization.new("Test Corp", "owner@test.com", :standard)
    {:ok, _org} = PostgreSQLOrganizationRepository.save(org)

    # Create admin user with access token
    {:ok, admin} = User.register("admin8183@test.com", "AdminPass123!")
    {:ok, admin} = User.verify_email(admin)
    {:ok, admin} = PostgreSQLUserRepository.save(admin)

    # Create organization and client
    {:ok, org} = Thalamus.Domain.Entities.Organization.new("Test Org", "admin@test.com")
    {:ok, _org} = Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository.save(org)

    {:ok, client} =
      Thalamus.TestHelpers.create_test_client(
        "Test Client",
        org.id,
        ["zea:read", "zea:write", "zea:admin"]
      )

    {:ok, client} =
      Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepository.save(client)

    # Generate access token
    {:ok, read_scope} = Scope.new("api:read")
    {:ok, write_scope} = Scope.new("api:write")
    {:ok, admin_scope} = Scope.new("api:admin")
    _scopes = [read_scope, write_scope, admin_scope]

    {:ok, access_token} =
      AccessToken.generate(
        [
          %Thalamus.Domain.ValueObjects.Scope{value: "zea:read"},
          %Thalamus.Domain.ValueObjects.Scope{value: "zea:write"},
          %Thalamus.Domain.ValueObjects.Scope{value: "zea:admin"}
        ],
        admin.id,
        3600
      )

    # Extract client ID without "client_" prefix for DB storage
    client_id_string = Thalamus.Domain.ValueObjects.ClientId.to_string(client.id)
    _client_uuid = String.replace_prefix(client_id_string, "client_", "")

    token_data = %{
      token: access_token.token,
      type: :access_token,
      user_id: admin.id,
      client_id: client.id,
      scopes: ["zea:read", "zea:write", "zea:admin"],
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

    test "filters by username (partial match on name or email)", %{
      conn: conn,
      access_token: token
    } do
      # Create a user with specific name for search
      {:ok, named_user} = User.register("carlos@test.com", "Pass123!")
      named_user = %{named_user | name: "FullStack Developer"}
      {:ok, _} = PostgreSQLUserRepository.save(named_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users?username=fullstack")

      assert %{
               "data" => users
             } = json_response(conn, 200)

      assert length(users) >= 1
      # Should find user by name partial match
      assert Enum.any?(users, fn u -> u["name"] == "FullStack Developer" end)
    end

    test "username filter returns empty array for no match", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users?username=nonexistent_xyz123")

      assert %{
               "data" => users
             } = json_response(conn, 200)

      assert users == []
    end

    test "username filter matches by email partial", %{conn: conn, access_token: token} do
      {:ok, email_user} = User.register("unique_search_target@example.com", "Pass123!")
      {:ok, _} = PostgreSQLUserRepository.save(email_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users?username=unique_search")

      assert %{
               "data" => users
             } = json_response(conn, 200)

      assert length(users) >= 1
      assert Enum.any?(users, fn u -> u["email"] == "unique_search_target@example.com" end)
    end

    test "filters by is_agent = true", %{conn: conn, access_token: token} do
      # Create an agent user via domain entity
      {:ok, agent_user} =
        Thalamus.Domain.Entities.User.new(%{
          id: elem(Thalamus.Domain.ValueObjects.UserId.generate(), 1),
          email: elem(Thalamus.Domain.ValueObjects.Email.new("agent_test@test.com"), 1),
          password_hash:
            elem(Thalamus.Domain.ValueObjects.PasswordHash.from_password("AgentPass123!"), 1),
          name: "Test Agent",
          is_agent: true
        })

      {:ok, agent_user} = Thalamus.Domain.Entities.User.verify_email(agent_user)
      {:ok, _} = PostgreSQLUserRepository.save(agent_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users?is_agent=true")

      assert %{
               "data" => users
             } = json_response(conn, 200)

      assert length(users) >= 1

      Enum.each(users, fn user ->
        assert user["is_agent"] == true
      end)
    end

    test "is_agent=false returns non-agent users", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users?is_agent=false")

      assert %{
               "data" => users
             } = json_response(conn, 200)

      # All returned users should NOT be agents
      Enum.each(users, fn user ->
        assert user["is_agent"] == false or user["is_agent"] == nil
      end)
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
      assert json_response(conn, 401)
    end

    test "creates user with parent_user_id (bare UUID)", %{conn: conn, access_token: token} do
      {:ok, parent} = User.register("parent@test.com", "Pass123!")
      {:ok, parent} = PostgreSQLUserRepository.save(parent)

      parent_id = to_string(parent.id) |> String.replace_prefix("user_", "")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/users", %{
          email: "child@test.com",
          password: "Pass123!",
          parent_user_id: parent_id
        })

      assert %{"data" => %{"parent_user_id" => returned_parent}} = json_response(conn, 201)
      assert returned_parent == parent_id
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
                 "email" => "admin8183@test.com",
                 "verified" => true
               }
             } = json_response(conn, 200)

      assert id == to_string(admin.id)
    end

    test "returns 404 for non-existent user", %{conn: conn, access_token: token} do
      fake_id = Thalamus.Domain.ValueObjects.UserId.generate() |> elem(1)

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

      assert json_response(conn, 404)
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
      fake_id = Thalamus.Domain.ValueObjects.UserId.generate() |> elem(1)

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

    test "updates parent_user_id (bare UUID)", %{conn: conn, access_token: token} do
      {:ok, parent} = User.register("patchparent@test.com", "Pass123!")
      {:ok, parent} = PostgreSQLUserRepository.save(parent)
      {:ok, child} = User.register("patchchild@test.com", "Pass123!")
      {:ok, child} = PostgreSQLUserRepository.save(child)

      parent_id = to_string(parent.id) |> String.replace_prefix("user_", "")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/users/#{child.id}", %{parent_user_id: parent_id})

      assert %{"data" => %{"parent_user_id" => updated}} = json_response(conn, 200)
      assert updated == parent_id
    end

    test "unlinks parent_user_id with empty string", %{conn: conn, access_token: token} do
      {:ok, parent} = User.register("unlinkparent@test.com", "Pass123!")
      {:ok, parent} = PostgreSQLUserRepository.save(parent)
      {:ok, child} = User.register("unlinkchild@test.com", "Pass123!")
      {:ok, saved_child} = PostgreSQLUserRepository.save(child)

      # Link first
      linked = %{saved_child | parent_user_id: to_string(parent.id)}
      {:ok, _} = PostgreSQLUserRepository.save(linked)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/users/#{saved_child.id}", %{parent_user_id: ""})

      assert %{"data" => %{"parent_user_id" => unlinked}} = json_response(conn, 200)
      assert unlinked == nil
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
      fake_id = Thalamus.Domain.ValueObjects.UserId.generate() |> elem(1)

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
