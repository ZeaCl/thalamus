defmodule ThalamusWeb.API.OrganizationControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Domain.ValueObjects.AccessToken

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLTokenRepository
  }

  setup do
    # Create admin user with access token
    {:ok, admin} = User.register("admin@test.com", "AdminPass123!")
    {:ok, admin} = User.verify_email(admin)
    {:ok, admin} = PostgreSQLUserRepository.save(admin)

    # Create organization and client
    {:ok, org} = Thalamus.Domain.Entities.Organization.new("Test Org", "admin@test.com")
    {:ok, org} = Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository.save(org)

    {:ok, client} =
      Thalamus.TestHelpers.create_test_client(
        "Test Client",
        org.id,
        ["zea:read", "zea:write", "zea:admin"]
      )

    {:ok, client} =
      Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepository.save(client)

    # Generate access token
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

  describe "GET /api/organizations" do
    test "lists all organizations", %{conn: conn, access_token: token} do
      # Create test organizations
      {:ok, org1} = Organization.new("Acme Corp", "owner1@acme.com", :professional)
      {:ok, _} = PostgreSQLOrganizationRepository.save(org1)

      {:ok, org2} = Organization.new("Beta Inc", "owner2@beta.com", :starter)
      {:ok, _} = PostgreSQLOrganizationRepository.save(org2)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/organizations")

      assert %{
               "data" => orgs
             } = json_response(conn, 200)

      assert is_list(orgs)
      assert length(orgs) >= 2
    end

    test "filters organizations by status", %{conn: conn, access_token: token} do
      {:ok, active_org} = Organization.new("Active Corp", "active@test.com", :professional)
      verified_org = %{active_org | status: :active, verified_at: DateTime.utc_now()}
      {:ok, _} = PostgreSQLOrganizationRepository.save(verified_org)

      {:ok, pending_org} = Organization.new("Pending Corp", "pending@test.com", :starter)
      {:ok, _} = PostgreSQLOrganizationRepository.save(pending_org)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/organizations?status=active")

      assert %{
               "data" => orgs
             } = json_response(conn, 200)

      Enum.each(orgs, fn org ->
        assert org["status"] == "active"
      end)
    end

    test "filters organizations by plan type", %{conn: conn, access_token: token} do
      {:ok, pro_org} = Organization.new("Pro Corp", "pro@test.com", :professional)
      {:ok, _} = PostgreSQLOrganizationRepository.save(pro_org)

      {:ok, free_org} = Organization.new("Free Corp", "free@test.com", :free)
      {:ok, _} = PostgreSQLOrganizationRepository.save(free_org)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/organizations?plan_type=professional")

      assert %{
               "data" => orgs
             } = json_response(conn, 200)

      Enum.each(orgs, fn org ->
        assert org["plan_type"] == "professional"
      end)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/organizations")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/organizations" do
    test "creates new organization with valid data", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/organizations", %{
          name: "New Corp",
          owner_email: "owner@newcorp.com",
          plan_type: "professional"
        })

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "New Corp",
                 "owner_email" => "owner@newcorp.com",
                 "plan_type" => "professional",
                 "status" => status
               }
             } = json_response(conn, 201)

      assert is_binary(id)
      assert status in ["pending_verification", "active"]
    end

    test "creates organization with default free plan", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/organizations", %{
          name: "Free Corp",
          owner_email: "owner@freecorp.com"
        })

      assert %{
               "data" => %{
                 "plan_type" => "free"
               }
             } = json_response(conn, 201)
    end

    test "returns error with invalid email", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/organizations", %{
          name: "Bad Email Corp",
          owner_email: "not-an-email",
          plan_type: "starter"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "returns error with missing name", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/organizations", %{
          owner_email: "owner@test.com"
        })

      assert %{
               "error" => _
             } = json_response(conn, 400)
    end

    test "requires authentication", %{conn: conn} do
      conn =
        post(conn, ~p"/api/organizations", %{
          name: "Unauth Corp",
          owner_email: "owner@test.com"
        })

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/organizations/:id" do
    test "returns organization by id", %{conn: conn, access_token: token} do
      {:ok, org} = Organization.new("Get Corp", "owner@getcorp.com", :professional)
      {:ok, org} = PostgreSQLOrganizationRepository.save(org)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/organizations/#{org.id}")

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "Get Corp",
                 "owner_email" => "owner@getcorp.com"
               }
             } = json_response(conn, 200)

      assert id == to_string(org.id)
    end

    test "includes members in response", %{conn: conn, access_token: token} do
      {:ok, org} = Organization.new("Members Corp", "owner@members.com", :professional)

      # Add a member
      {:ok, user} = Thalamus.Domain.ValueObjects.UserId.generate()
      {:ok, email} = Thalamus.Domain.ValueObjects.Email.new("member@test.com")

      {:ok, org_with_member} =
        Organization.add_member(
          org,
          user,
          email,
          :member
        )

      {:ok, org_with_member} = PostgreSQLOrganizationRepository.save(org_with_member)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/organizations/#{org_with_member.id}")

      assert %{
               "data" => %{
                 "members" => members
               }
             } = json_response(conn, 200)

      assert is_list(members)
      assert length(members) >= 1
    end

    test "returns 404 for non-existent organization", %{conn: conn, access_token: token} do
      fake_id = Thalamus.Domain.ValueObjects.OrganizationId.generate() |> elem(1)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/organizations/#{fake_id}")

      assert %{
               "error" => _
             } = json_response(conn, 404)
    end

    test "requires authentication", %{conn: conn} do
      {:ok, org} = Organization.new("Auth Corp", "owner@auth.com", :free)
      {:ok, org} = PostgreSQLOrganizationRepository.save(org)

      conn = get(conn, ~p"/api/organizations/#{org.id}")

      assert json_response(conn, 401)
    end
  end

  describe "PATCH /api/organizations/:id" do
    test "updates organization name", %{conn: conn, access_token: token} do
      {:ok, org} = Organization.new("Old Name", "owner@test.com", :starter)
      {:ok, org} = PostgreSQLOrganizationRepository.save(org)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/organizations/#{org.id}", %{
          name: "New Name"
        })

      assert %{
               "data" => %{
                 "id" => _,
                 "name" => "New Name"
               }
             } = json_response(conn, 200)
    end

    test "updates organization plan", %{conn: conn, access_token: token} do
      {:ok, org} = Organization.new("Upgrade Corp", "owner@test.com", :free)
      {:ok, org} = PostgreSQLOrganizationRepository.save(org)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/organizations/#{org.id}", %{
          plan_type: "enterprise"
        })

      assert %{
               "data" => %{
                 "plan_type" => "enterprise"
               }
             } = json_response(conn, 200)
    end

    test "updates organization status", %{conn: conn, access_token: token} do
      {:ok, org} = Organization.new("Status Corp", "owner@test.com", :starter)
      {:ok, org} = PostgreSQLOrganizationRepository.save(org)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/organizations/#{org.id}", %{
          status: "suspended"
        })

      assert %{
               "data" => %{
                 "status" => "suspended"
               }
             } = json_response(conn, 200)
    end

    test "returns 404 for non-existent organization", %{conn: conn, access_token: token} do
      fake_id = Thalamus.Domain.ValueObjects.OrganizationId.generate() |> elem(1)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/organizations/#{fake_id}", %{
          name: "Not Found"
        })

      assert json_response(conn, 404)
    end

    test "requires authentication", %{conn: conn} do
      {:ok, org} = Organization.new("No Auth", "owner@test.com", :free)
      {:ok, org} = PostgreSQLOrganizationRepository.save(org)

      conn =
        patch(conn, ~p"/api/organizations/#{org.id}", %{
          name: "New Name"
        })

      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/organizations/:id" do
    test "deletes organization", %{conn: conn, access_token: token} do
      {:ok, org} = Organization.new("Delete Corp", "owner@delete.com", :free)
      {:ok, org} = PostgreSQLOrganizationRepository.save(org)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/organizations/#{org.id}")

      assert response(conn, 204)

      # Verify organization is deleted
      {:ok, deleted_org} = PostgreSQLOrganizationRepository.find_by_id(org.id)
      assert deleted_org.status == :cancelled
    end

    test "returns 404 for non-existent organization", %{conn: conn, access_token: token} do
      fake_id = Thalamus.Domain.ValueObjects.OrganizationId.generate() |> elem(1)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/organizations/#{fake_id}")

      assert json_response(conn, 404)
    end

    test "requires authentication", %{conn: conn} do
      {:ok, org} = Organization.new("Auth Delete", "owner@test.com", :free)
      {:ok, org} = PostgreSQLOrganizationRepository.save(org)

      conn = delete(conn, ~p"/api/organizations/#{org.id}")

      assert json_response(conn, 401)
    end
  end
end
