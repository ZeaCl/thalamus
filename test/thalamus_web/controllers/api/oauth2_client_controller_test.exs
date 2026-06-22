defmodule ThalamusWeb.API.OAuth2ClientControllerTest do
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
    # Create organization
    {:ok, org} = Organization.new("Test Corp", "owner@test.com", :standard)
    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    # Create admin user with access token
    {:ok, admin} = User.register("admin8183@test.com", "AdminPass123!")
    {:ok, admin} = User.verify_email(admin)
    {:ok, admin} = PostgreSQLUserRepository.save(admin)

    # Create a test OAuth2 client for token storage
    {:ok, test_client} =
      TestHelpers.create_test_client(
        "Test Client",
        org.id,
        ["zea:read", "zea:write", "zea:admin"]
      )

    {:ok, test_client} = PostgreSQLOAuth2ClientRepository.save(test_client)

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

    token_data = %{
      token: access_token.token,
      type: :access_token,
      user_id: admin.id,
      client_id: to_string(test_client.id),
      scopes: ["zea:read", "zea:write", "zea:admin"],
      expires_at: access_token.expires_at
    }

    :ok = PostgreSQLTokenRepository.store(token_data)

    {:ok, %{admin: admin, org: org, access_token: access_token.token}}
  end

  describe "GET /api/clients" do
    test "lists all OAuth2 clients", %{conn: conn, org: org, access_token: token} do
      # Create test clients
      {:ok, client1} =
        TestHelpers.create_test_client(
          "Web App",
          org.id,
          ["openid", "profile"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:authorization_code, :refresh_token]
        )

      {:ok, _} = PostgreSQLOAuth2ClientRepository.save(client1)

      {:ok, client2} =
        TestHelpers.create_test_client(
          "Mobile App",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:4000/callback"],
          grant_types: [:authorization_code]
        )

      {:ok, _} = PostgreSQLOAuth2ClientRepository.save(client2)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/clients")

      assert %{
               "data" => clients
             } = json_response(conn, 200)

      assert is_list(clients)
      assert length(clients) >= 2
    end

    test "filters clients by organization", %{conn: conn, org: org, access_token: token} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Org Client",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:client_credentials]
        )

      {:ok, _} = PostgreSQLOAuth2ClientRepository.save(client)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/clients?organization_id=#{to_string(org.id)}")

      assert %{
               "data" => clients
             } = json_response(conn, 200)

      Enum.each(clients, fn client ->
        assert client["organization_id"] == to_string(org.id)
      end)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/clients")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/clients" do
    test "creates new OAuth2 client with valid data", %{conn: conn, org: org, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/clients", %{
          name: "New Client",
          organization_id: to_string(org.id),
          redirect_uris: ["http://localhost:3000/callback", "http://localhost:3000/auth"],
          grant_types: ["authorization_code", "refresh_token"],
          scopes: ["zea:read", "zea:write"]
        })

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "New Client",
                 "organization_id" => org_id,
                 "redirect_uris" => redirect_uris,
                 "grant_types" => grant_types,
                 "scopes" => scopes,
                 "client_secret" => secret
               }
             } = json_response(conn, 201)

      assert is_binary(id)
      assert org_id == to_string(org.id)
      assert is_list(redirect_uris)
      assert is_list(grant_types)
      assert is_list(scopes)
      assert is_binary(secret)
    end

    test "creates client with default grant types and scopes", %{
      conn: conn,
      org: org,
      access_token: token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/clients", %{
          name: "Default Client",
          organization_id: to_string(org.id),
          redirect_uris: ["http://localhost:3000/callback"]
        })

      assert %{
               "data" => %{
                 "grant_types" => grant_types,
                 "scopes" => scopes
               }
             } = json_response(conn, 201)

      assert is_list(grant_types)
      assert is_list(scopes)
    end

    test "returns error with invalid redirect URI", %{conn: conn, org: org, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/clients", %{
          name: "Bad URI Client",
          organization_id: to_string(org.id),
          redirect_uris: ["not-a-valid-uri"],
          grant_types: ["authorization_code"],
          scopes: ["zea:read"]
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with invalid grant type", %{conn: conn, org: org, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/clients", %{
          name: "Bad Grant Client",
          organization_id: to_string(org.id),
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: ["invalid_grant"],
          scopes: ["zea:read"]
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with missing name", %{conn: conn, org: org, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/clients", %{
          organization_id: to_string(org.id),
          redirect_uris: ["http://localhost:3000/callback"]
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "requires authentication", %{conn: conn, org: org} do
      conn =
        post(conn, ~p"/api/clients", %{
          name: "Unauth Client",
          organization_id: to_string(org.id),
          redirect_uris: ["http://localhost:3000/callback"]
        })

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/clients/:id" do
    test "returns client by id", %{conn: conn, org: org, access_token: token} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Get Client",
          org.id,
          ["openid", "profile"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:authorization_code, :refresh_token]
        )

      {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/clients/#{to_string(client.id)}")

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "Get Client",
                 "redirect_uris" => redirect_uris,
                 "grant_types" => grant_types
               }
             } = json_response(conn, 200)

      assert id == to_string(client.id)
      assert is_list(redirect_uris)
      assert is_list(grant_types)
    end

    test "does not include secret in response", %{conn: conn, org: org, access_token: token} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Secret Client",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:client_credentials]
        )

      {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/clients/#{to_string(client.id)}")

      response = json_response(conn, 200)

      # Secret should not be in GET response (only in POST create)
      refute Map.has_key?(response["data"], "secret")
    end

    test "returns 404 for non-existent client", %{conn: conn, access_token: token} do
      {:ok, fake_id} = Thalamus.Domain.ValueObjects.ClientId.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/clients/#{to_string(fake_id)}")

      assert %{
               "error" => _
             } = json_response(conn, 404)
    end

    test "requires authentication", %{conn: conn, org: org} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Auth Client",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:authorization_code]
        )

      {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn = get(conn, ~p"/api/clients/#{to_string(client.id)}")

      assert json_response(conn, 401)
    end
  end

  describe "PATCH /api/clients/:id" do
    test "updates client name", %{conn: conn, org: org, access_token: token} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Old Name",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:authorization_code]
        )

      {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/clients/#{to_string(client.id)}", %{
          name: "New Name"
        })

      assert %{
               "data" => %{
                 "id" => _,
                 "name" => "New Name"
               }
             } = json_response(conn, 200)
    end

    test "updates redirect URIs", %{conn: conn, org: org, access_token: token} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Update URIs",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:authorization_code]
        )

      {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

      new_uris = ["http://localhost:4000/callback", "http://app.com/callback"]

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/clients/#{to_string(client.id)}", %{
          redirect_uris: new_uris
        })

      assert %{
               "data" => %{
                 "redirect_uris" => redirect_uris
               }
             } = json_response(conn, 200)

      assert redirect_uris == new_uris
    end

    test "updates allowed scopes", %{conn: conn, org: org, access_token: token} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Update Scopes",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:authorization_code]
        )

      {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/clients/#{to_string(client.id)}", %{
          allowed_scopes: ["zea:read", "write", "admin"]
        })

      assert %{
               "data" => %{
                 "scopes" => scopes
               }
             } = json_response(conn, 200)

      assert "api:admin" in scopes
    end

    test "returns 404 for non-existent client", %{conn: conn, access_token: token} do
      {:ok, fake_id} = Thalamus.Domain.ValueObjects.ClientId.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/clients/#{to_string(fake_id)}", %{
          name: "Not Found"
        })

      assert json_response(conn, 404)
    end

    test "requires authentication", %{conn: conn, org: org} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "No Auth",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:authorization_code]
        )

      {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn =
        patch(conn, ~p"/api/clients/#{to_string(client.id)}", %{
          name: "New Name"
        })

      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/clients/:id" do
    test "deletes client", %{conn: conn, org: org, access_token: token} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Delete Client",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:client_credentials]
        )

      {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/clients/#{to_string(client.id)}")

      assert response(conn, 204)

      # Verify client is deleted
      assert {:error, :not_found} = PostgreSQLOAuth2ClientRepository.find_by_id(client.id)
    end

    test "returns 404 for non-existent client", %{conn: conn, access_token: token} do
      {:ok, fake_id} = Thalamus.Domain.ValueObjects.ClientId.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/clients/#{to_string(fake_id)}")

      assert json_response(conn, 404)
    end

    test "requires authentication", %{conn: conn, org: org} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Auth Delete",
          org.id,
          ["openid"],
          redirect_uris: ["http://localhost:3000/callback"],
          grant_types: [:authorization_code]
        )

      {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn = delete(conn, ~p"/api/clients/#{to_string(client.id)}")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/clients/:id/rotate-secret" do
    test "rotates client secret", %{conn: conn, org: org, access_token: token} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "Rotate Secret",
          org.id,
          ["openid"],
          client_type: :confidential
        )

      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/clients/#{to_string(saved_client.id)}/rotate-secret")

      assert %{
               "data" => %{
                 "client_secret" => new_secret,
                 "client_id" => client_id,
                 "rotated_at" => _
               },
               "message" => message
             } = json_response(conn, 200)

      assert is_binary(new_secret)
      assert String.length(new_secret) > 20
      assert client_id == to_string(saved_client.id)
      assert String.contains?(message, "IMPORTANT")

      # Verify the new secret works by attempting to use it
      # (the secret in DB should be hashed now)
      {:ok, reloaded_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)
      assert reloaded_client.client_secret != nil
    end

    test "returns error for public clients", %{conn: conn, org: org, access_token: token} do
      # Create a public client
      {:ok, public_client} =
        TestHelpers.create_test_client(
          "Public Client",
          org.id,
          ["openid"],
          client_type: :public
        )

      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(public_client)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/clients/#{to_string(saved_client.id)}/rotate-secret")

      assert %{
               "error" => error
             } = json_response(conn, 400)

      assert String.contains?(error, "public")
    end

    test "returns 404 for non-existent client", %{conn: conn, access_token: token} do
      fake_id = "client_00000000-0000-0000-0000-000000000000"

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/clients/#{fake_id}/rotate-secret")

      assert %{"error" => _} = json_response(conn, 404)
    end

    test "requires authentication", %{conn: conn, org: org} do
      {:ok, client} =
        TestHelpers.create_test_client(
          "No Auth Rotate",
          org.id,
          ["openid"],
          client_type: :confidential
        )

      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      conn = post(conn, ~p"/api/clients/#{to_string(saved_client.id)}/rotate-secret")

      assert json_response(conn, 401)
    end
  end
end
