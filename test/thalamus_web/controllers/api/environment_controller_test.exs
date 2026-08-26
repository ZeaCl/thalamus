defmodule ThalamusWeb.API.EnvironmentControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Domain.ValueObjects.{AccessToken, Scope}

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLOAuth2ClientRepository,
    PostgreSQLTokenRepository,
    PostgreSQLEnvironmentRepository
  }

  setup %{conn: conn} do
    # Create organization
    {:ok, org} =
      Organization.new(
        "Acme Corp #{System.unique_integer([:positive])}",
        "owner_#{System.unique_integer([:positive])}@test.com",
        :standard
      )

    {:ok, saved_org} = PostgreSQLOrganizationRepository.save(org)

    # Create admin user with access token
    {:ok, admin} =
      User.register("admin_#{System.unique_integer([:positive])}@test.com", "AdminPass123!")

    {:ok, admin} = User.verify_email(admin)
    {:ok, admin} = PostgreSQLUserRepository.save(admin)

    {:ok, client} =
      Thalamus.TestHelpers.create_test_client(
        "Test Client",
        saved_org.id,
        ["zea:read", "zea:write", "zea:admin"]
      )

    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    {:ok, access_token} =
      AccessToken.generate(
        [
          %Scope{value: "zea:read"},
          %Scope{value: "zea:write"},
          %Scope{value: "zea:admin"}
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

    authed_conn =
      conn
      |> put_req_header("authorization", "Bearer #{access_token.token}")
      |> put_req_header("content-type", "application/json")

    %{conn: authed_conn, org: saved_org}
  end

  describe "GET /api/organizations/:organization_id/environments" do
    test "lists environments for organization", %{conn: conn, org: org} do
      {:ok, _} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "production",
          name: "Producción",
          type: :production,
          is_default: true
        })

      {:ok, _} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "staging",
          name: "Staging",
          type: :staging,
          is_default: false
        })

      conn = get(conn, ~p"/api/organizations/#{org.id}/environments")
      assert json_response(conn, 200)["data"] |> length() >= 2
    end
  end

  describe "POST /api/organizations/:organization_id/environments" do
    test "creates new environment with valid params", %{conn: conn, org: org} do
      payload = %{
        "slug" => "test-sandbox",
        "name" => "Test Sandbox",
        "type" => "sandbox",
        "description" => "Ephemeral sandbox environment"
      }

      conn = post(conn, ~p"/api/organizations/#{org.id}/environments", payload)
      assert response = json_response(conn, 201)["data"]
      assert response["slug"] == "test-sandbox"
      assert response["name"] == "Test Sandbox"
      assert response["type"] == "sandbox"
    end
  end

  describe "GET /api/organizations/:organization_id/environments/:id" do
    test "retrieves environment by slug or id", %{conn: conn, org: org} do
      {:ok, env} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "demo-env",
          name: "Demo",
          type: :demo
        })

      # Fetch by slug
      conn_slug = get(conn, ~p"/api/organizations/#{org.id}/environments/demo-env")
      assert json_response(conn_slug, 200)["data"]["id"] == env.id

      # Fetch by id
      conn_id = get(conn, ~p"/api/organizations/#{org.id}/environments/#{env.id}")
      assert json_response(conn_id, 200)["data"]["slug"] == "demo-env"
    end
  end

  describe "POST /api/organizations/:organization_id/environments/:id/default" do
    test "switches default environment", %{conn: conn, org: org} do
      {:ok, prod} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "prod",
          name: "Prod",
          type: :production,
          is_default: true
        })

      {:ok, staging} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "staging",
          name: "Staging",
          type: :staging,
          is_default: false
        })

      conn = post(conn, ~p"/api/organizations/#{org.id}/environments/#{staging.id}/default")
      assert json_response(conn, 200)["data"]["is_default"] == true

      # Check prod is no longer default
      {:ok, updated_prod} = PostgreSQLEnvironmentRepository.get(prod.id)
      assert updated_prod.is_default == false
    end
  end

  describe "DELETE /api/organizations/:organization_id/environments/:id" do
    test "protects default environment from deletion", %{conn: conn, org: org} do
      {:ok, prod} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "prod-default",
          name: "Prod",
          type: :production,
          is_default: true
        })

      conn = delete(conn, ~p"/api/organizations/#{org.id}/environments/#{prod.id}")
      assert json_response(conn, 422)["error"] =~ "default"
    end

    test "deletes non-default sandbox environment", %{conn: conn, org: org} do
      {:ok, sandbox} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "temp-sandbox",
          name: "Temp Sandbox",
          type: :sandbox,
          is_default: false
        })

      conn = delete(conn, ~p"/api/organizations/#{org.id}/environments/#{sandbox.id}")
      assert response(conn, 204)
    end
  end
end
