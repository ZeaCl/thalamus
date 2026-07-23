defmodule ThalamusWeb.API.PersonalAccessTokenControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Domain.ValueObjects.{AccessToken, Scope}
  alias Thalamus.TestHelpers

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLOAuth2ClientRepository,
    PostgreSQLTokenRepository
  }

  setup do
    # Create organization for OAuth2 client
    {:ok, org} = Organization.new("Test Corp", "owner@test.com", :standard)
    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    # Create admin user with access token
    {:ok, admin} = User.register("admin8183@test.com", "AdminPass123!")
    {:ok, admin} = User.verify_email(admin)
    {:ok, admin} = PostgreSQLUserRepository.save(admin)

    # Create OAuth2 client
    {:ok, client} =
      TestHelpers.create_test_client("Test Client", org.id, ["api:read", "api:write", "api:admin"])

    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    # Generate access token
    {:ok, read_scope} = Scope.new("api:read")
    {:ok, write_scope} = Scope.new("api:write")
    {:ok, admin_scope} = Scope.new("api:admin")
    scopes = [read_scope, write_scope, admin_scope]

    {:ok, access_token} =
      AccessToken.generate(
        scopes,
        admin.id,
        3600
      )

    # Extract client ID without "client_" prefix for DB storage
    client_id_string = Thalamus.Domain.ValueObjects.ClientId.to_string(client.id)
    client_uuid = String.replace_prefix(client_id_string, "client_", "")

    token_data = %{
      token: access_token.token,
      type: :access_token,
      user_id: admin.id,
      client_id: client_uuid,
      scopes: ["api:read", "api:write", "api:admin"],
      expires_at: access_token.expires_at
    }

    :ok = PostgreSQLTokenRepository.store(token_data)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> Plug.Conn.put_req_header("authorization", "Bearer #{access_token.token}")

    {:ok, %{conn: conn, user_id: to_string(admin.id), org_id: to_string(org.id)}}
  end

  describe "POST /api/personal-access-tokens" do
    test "creates a personal access token successfully", %{
      conn: conn,
      user_id: user_id,
      org_id: org_id
    } do
      conn =
        post(conn, ~p"/api/personal-access-tokens", %{
          "name" => "My Token",
          "organization_id" => org_id,
          "scopes" => ["zea:read"]
        })

      user_uuid = String.replace_prefix(user_id, "user_", "")
      org_uuid = String.replace_prefix(org_id, "org_", "")

      assert %{
               "data" => %{
                 "name" => "My Token",
                 "user_id" => ^user_uuid,
                 "organization_id" => ^org_uuid,
                 "scopes" => ["zea:read"]
               },
               "token" => token
             } = json_response(conn, 201)

      assert String.starts_with?(token, "th_pat_")
    end

    test "returns 400 when name is missing", %{conn: conn} do
      org_id = Ecto.UUID.generate()

      conn = post(conn, ~p"/api/personal-access-tokens", %{
        "organization_id" => org_id
      })

      assert json_response(conn, 400) == %{"error" => "name is required"}
    end
  end

  describe "GET /api/personal-access-tokens" do
    test "lists personal access tokens for the authenticated user", %{
      conn: conn,
      user_id: user_id,
      org_id: org_id
    } do
      # Create a token first

      post(conn, ~p"/api/personal-access-tokens", %{
        "name" => "My Token",
        "organization_id" => org_id,
        "scopes" => ["zea:read"]
      })

      # Now fetch list
      conn = get(conn, ~p"/api/personal-access-tokens")

      assert %{"data" => [token_data]} = json_response(conn, 200)
      assert token_data["name"] == "My Token"

      user_uuid = String.replace_prefix(user_id, "user_", "")
      assert token_data["user_id"] == user_uuid
    end
  end

  describe "DELETE /api/personal-access-tokens/:id" do
    test "deletes personal access token successfully", %{
      conn: conn,
      user_id: _user_id,
      org_id: org_id
    } do
      res_conn =
        post(conn, ~p"/api/personal-access-tokens", %{
          "name" => "My Token to Delete",
          "organization_id" => org_id,
          "scopes" => ["zea:read"]
        })

      %{"data" => %{"id" => pat_id}} = json_response(res_conn, 201)

      del_conn = delete(conn, ~p"/api/personal-access-tokens/#{pat_id}")

      assert json_response(del_conn, 200)["message"] == "Token revoked successfully"
    end
  end
end
