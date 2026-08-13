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
  end
end
