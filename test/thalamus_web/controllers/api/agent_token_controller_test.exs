defmodule ThalamusWeb.API.AgentTokenControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.ValueObjects.UserId

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/internal/agent-token" do
    test "creates an agent token successfully when valid user_id is provided", %{conn: conn} do
      {:ok, email} = Thalamus.Domain.ValueObjects.Email.new("test@example.com")
      {:ok, org} = Thalamus.Domain.Entities.Organization.new("Test Org", to_string(email))

      {:ok, saved_org} =
        Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository.save(org)

      saved_org_uuid =
        String.replace_prefix(
          Thalamus.Domain.ValueObjects.OrganizationId.to_string(saved_org.id),
          "org_",
          ""
        )

      user_uuid = Ecto.UUID.generate()

      {:ok, user_email} = Thalamus.Domain.ValueObjects.Email.new("user@example.com")
      {:ok, _pwd_hash} = Thalamus.Domain.ValueObjects.PasswordHash.from_password("Password123!")
      {:ok, user} = Thalamus.Domain.Entities.User.register(to_string(user_email), "Password123!")
      {:ok, u_id} = Thalamus.Domain.ValueObjects.UserId.new(user_uuid)
      user = %{user | id: u_id}
      {:ok, saved_user} = Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository.save(user)

      saved_user_uuid =
        String.replace_prefix(
          Thalamus.Domain.ValueObjects.UserId.to_string(saved_user.id),
          "user_",
          ""
        )

      conn =
        post(conn, ~p"/api/internal/agent-token", %{
          "user_id" => saved_user_uuid,
          "organization_id" => saved_org_uuid,
          "scopes" => ["venture:read"]
        })

      assert %{
               "scopes" => ["venture:read"],
               "expires_in" => 3600,
               "token" => token
             } = json_response(conn, 201)

      assert String.starts_with?(token, "th_pat_")
    end

    test "returns 400 when user_id is missing", %{conn: conn} do
      conn =
        post(conn, ~p"/api/internal/agent-token", %{
          "scopes" => ["venture:read"]
        })

      assert json_response(conn, 400)["error"] == "Missing user_id"
    end
  end
end
