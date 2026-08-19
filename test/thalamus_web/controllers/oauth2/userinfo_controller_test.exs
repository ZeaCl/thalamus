defmodule ThalamusWeb.OAuth2.UserinfoControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Infrastructure.JwtSigner

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository
  }

  setup do
    {:ok, org} = Organization.new("Test Corp", "owner@test.com", :standard)
    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    {:ok, user} = User.register("user@test.com", "Password123!")
    {:ok, user} = User.verify_email(user)
    user = %{user | organization_id: org.id}
    {:ok, user} = PostgreSQLUserRepository.save(user)

    %{user: user, org: org}
  end

  describe "GET /oauth/userinfo" do
    test "returns 401 when Authorization header is missing", %{conn: conn} do
      conn = get(conn, ~p"/oauth/userinfo")

      assert conn.status == 401
      assert %{"error" => "invalid_token"} = json_response(conn, 401)
    end

    test "returns user info for a stateless thalamus_api JWT not persisted in DB", %{
      conn: conn,
      user: user
    } do
      jwt =
        JwtSigner.sign_access_token(%{
          user_id: user.id,
          client_id: "thalamus_api",
          scope: "openid profile email",
          expires_in: 3600
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> get(~p"/oauth/userinfo")

      assert conn.status == 200

      response = json_response(conn, 200)
      assert response["sub"] == to_string(user.id)
      assert response["email"] == to_string(user.email)
      assert response["email_verified"] == true
    end

    test "returns 401 for an expired stateless thalamus_api JWT", %{conn: conn, user: user} do
      jwt =
        JwtSigner.sign_access_token(%{
          user_id: user.id,
          client_id: "thalamus_api",
          scope: "openid",
          expires_in: -1
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> get(~p"/oauth/userinfo")

      assert conn.status == 401
      assert %{"error" => "invalid_token"} = json_response(conn, 401)
    end

    test "returns 401 for a JWT from a non-thalamus_api client", %{conn: conn, user: user} do
      jwt =
        JwtSigner.sign_access_token(%{
          user_id: user.id,
          client_id: "other_client",
          scope: "openid",
          expires_in: 3600
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> get(~p"/oauth/userinfo")

      assert conn.status == 401
      assert %{"error" => "invalid_token"} = json_response(conn, 401)
    end

    test "returns 401 for an opaque token that is not in DB", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer random_opaque_token_123")
        |> get(~p"/oauth/userinfo")

      assert conn.status == 401
      assert %{"error" => "invalid_token"} = json_response(conn, 401)
    end

    test "returns 401 (not crash) for a JWT with a malformed header", %{conn: conn} do
      # Header is valid base64url but decodes to non-JSON bytes.
      header = Base.url_encode64(<<0, 0, 0>>, padding: false)
      payload = Base.url_encode64(~s({"client_id":"thalamus_api"}), padding: false)
      token = "#{header}.#{payload}.sig"

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/oauth/userinfo")

      assert conn.status == 401
      assert %{"error" => "invalid_token"} = json_response(conn, 401)
    end
  end

  describe "GET /oauth/userinfo with reports (hierarchy)" do
    setup :create_hierarchy

    test "includes reports for direct children/agents of the user", %{
      conn: conn,
      user: user,
      agent: agent
    } do
      jwt =
        JwtSigner.sign_access_token(%{
          user_id: user.id,
          client_id: "thalamus_api",
          scope: "openid profile email",
          expires_in: 3600
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> get(~p"/oauth/userinfo")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_list(response["reports"])
      assert length(response["reports"]) >= 1

      report = Enum.find(response["reports"], &(&1["id"] == to_string(agent.id)))
      assert report != nil
      assert report["is_agent"] == true
      assert report["role"] == "developer"
      assert report["name"] == agent.name
    end

    test "includes an empty reports array when there are no dependents", %{
      conn: conn,
      no_children_user: no_children_user
    } do
      jwt =
        JwtSigner.sign_access_token(%{
          user_id: no_children_user.id,
          client_id: "thalamus_api",
          scope: "openid profile email",
          expires_in: 3600
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> get(~p"/oauth/userinfo")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["reports"] == []
    end
  end

  defp create_hierarchy(%{conn: conn}) do
    alias Thalamus.Domain.ValueObjects.Email
    alias Thalamus.Domain.ValueObjects.PasswordHash
    alias Thalamus.Domain.ValueObjects.UserId

    {:ok, user} = User.register("alice@acme.corp", "Password123!")
    {:ok, user} = User.verify_email(user)
    {:ok, user} = PostgreSQLUserRepository.save(user)

    {:ok, agent_id} = UserId.generate()
    {:ok, email} = Email.new("copoilot@acme.corp")
    {:ok, password_hash} = PasswordHash.from_password("Password123!")

    {:ok, agent} =
      User.new(%{
        id: agent_id,
        email: email,
        password_hash: password_hash,
        name: "Acme Dev Copilot",
        is_agent: true,
        agent_config: %{"role" => "developer"},
        parent_user_id: to_string(user.id)
      })

    {:ok, agent} = PostgreSQLUserRepository.save(agent)
    {:ok, no_children_user} = User.register("solo@acme.corp", "Password123!")
    {:ok, no_children_user} = PostgreSQLUserRepository.save(no_children_user)

    {:ok, conn: conn, user: user, agent: agent, no_children_user: no_children_user}
  end
end
