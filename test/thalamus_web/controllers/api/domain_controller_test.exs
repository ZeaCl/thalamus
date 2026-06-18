defmodule ThalamusWeb.API.DomainControllerTest do
  use ThalamusWeb.ConnCase

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{
    DomainScopeSchema,
    UserDomainRoleSchema,
    UserSchema,
    OrganizationSchema
  }

  setup %{conn: conn} do
    {conn, user, org, token} = authenticate_api(conn)
    user_id = user.id.value |> String.replace_prefix("user_", "")
    org_id = org.id.value
    {:ok, conn: put_req_header(conn, "accept", "application/json"), user_id: user_id, org_id: org_id, token: token}
  end

  describe "POST /api/domains/register" do
    test "registers a new domain and scopes", %{conn: conn, token: token} do
      payload = %{
        "domain" => "venture",
        "scopes" => [
          %{"scope" => "venture:read", "description" => "Read"},
          %{"scope" => "venture:write", "description" => "Write"}
        ]
      }

      conn = put_req_header(conn, "authorization", "Bearer #{token}")
      conn = post(conn, "/api/domains/register", payload)
      assert json_response(conn, 200)["message"] =~ "registered with 2 scopes"

      scopes = Repo.all(DomainScopeSchema)
      assert length(scopes) == 2
      assert Enum.at(scopes, 0).domain == "venture"
    end

    test "returns bad request when params are missing", %{conn: conn, token: token} do
      conn = put_req_header(conn, "authorization", "Bearer #{token}")
      conn = post(conn, "/api/domains/register", %{})
      assert json_response(conn, 400)["error"] == "Missing required fields: domain, scopes"
    end
  end

  describe "GET /api/domains" do
    test "lists all domains", %{conn: conn, token: token} do
      # Insert scopes directly
      Repo.insert_all(DomainScopeSchema, [
        %{
          id: Ecto.UUID.generate(),
          domain: "test_domain",
          scope: "test_domain:read",
          description: "desc",
          inserted_at: DateTime.truncate(DateTime.utc_now(), :second),
          updated_at: DateTime.truncate(DateTime.utc_now(), :second)
        }
      ])

      conn = put_req_header(conn, "authorization", "Bearer #{token}")
      conn = get(conn, "/api/domains")
      response = json_response(conn, 200)
      
      data = response["data"]
      assert length(data) > 0
      assert Enum.any?(data, fn d -> d["domain"] == "test_domain" end)
    end
  end

  describe "POST /api/domains/roles/grant and POST /api/domains/roles/revoke" do
    test "grants a domain role to a user", %{conn: conn, org_id: org_id, user_id: user_id, token: token} do
      payload = %{
        "organization_id" => org_id,
        "user_id" => user_id,
        "domain" => "venture",
        "role" => "admin",
        "scopes" => ["venture:read", "venture:write"]
      }

      conn = put_req_header(conn, "authorization", "Bearer #{token}")
      conn = post(conn, "/api/domains/roles/grant", payload)
      assert json_response(conn, 201)["message"] == "Role granted"

      roles = Repo.all(UserDomainRoleSchema)
      assert length(roles) == 1
      
      role = hd(roles)
      assert role.domain == "venture"
      assert role.role == "admin"
      assert role.scopes == ["venture:read", "venture:write"]
      assert role.organization_id == org_id
      assert role.user_id == user_id
    end
    
    test "fails to grant role with invalid payload", %{conn: conn, token: token} do
       conn = put_req_header(conn, "authorization", "Bearer #{token}")
       conn = post(conn, "/api/domains/roles/grant", %{})
       assert json_response(conn, 400)["error"] =~ "Missing required fields"
    end

    test "revokes a domain role from a user", %{conn: conn, org_id: org_id, user_id: user_id, token: token} do
      # Grant role manually
      Repo.insert!(%UserDomainRoleSchema{
        organization_id: org_id,
        user_id: user_id,
        domain: "venture",
        role: "admin",
        scopes: ["venture:read"]
      })
      
      assert Repo.aggregate(UserDomainRoleSchema, :count, :id) == 1

      payload = %{
        "organization_id" => org_id,
        "user_id" => user_id,
        "domain" => "venture",
        "role" => "admin"
      }

      conn = put_req_header(conn, "authorization", "Bearer #{token}")
      conn = delete(conn, "/api/domains/roles/revoke", payload)
      assert json_response(conn, 200)["message"] == "Role revoked"

      assert Repo.aggregate(UserDomainRoleSchema, :count, :id) == 0
    end
    
    test "fails to revoke role with invalid payload", %{conn: conn, token: token} do
       conn = put_req_header(conn, "authorization", "Bearer #{token}")
       conn = delete(conn, "/api/domains/roles/revoke", %{})
       assert json_response(conn, 400)["error"] =~ "Missing required fields"
    end
  end

  describe "GET /api/domains/roles/:organization_id/:user_id" do
    setup %{org_id: org_id, user_id: user_id} do
      Repo.insert!(%UserDomainRoleSchema{
        organization_id: org_id,
        user_id: user_id,
        domain: "venture",
        role: "editor",
        scopes: ["venture:read"]
      })
      
      :ok
    end

    test "lists all roles for a user in an org", %{conn: conn, org_id: org_id, user_id: user_id, token: token} do
      conn = put_req_header(conn, "authorization", "Bearer #{token}")
      conn = get(conn, "/api/domains/roles?organization_id=#{org_id}&user_id=#{user_id}")
      response = json_response(conn, 200)
      
      data = response["data"]
      assert length(data) == 1
      assert hd(data)["domain"] == "venture"
      assert hd(data)["role"] == "editor"
    end
  end
end
