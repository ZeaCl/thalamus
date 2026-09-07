defmodule ThalamusWeb.OAuth2.AuthorizationControllerSocialTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.TestHelpers

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLOrganizationRepository,
    PostgreSQLOAuth2ClientRepository
  }

  setup do
    {:ok, org} = Organization.new("Social Test Org", "social_owner@test.com", :standard)
    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    {:ok, client} =
      TestHelpers.create_test_client(
        "Social Client",
        org.id,
        ["openid", "profile", "email"],
        redirect_uris: ["http://localhost:3000/callback"],
        grant_types: [:authorization_code]
      )

    # Set client as trusted (like glia_web_app)
    client = %{client | trusted: true}
    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    %{client: client, org: org}
  end

  describe "GET /oauth/authorize delegation with provider parameter" do
    test "delegates unauthenticated request directly to social provider init", %{
      conn: conn,
      client: client
    } do
      client_id = to_string(client.id)

      params = %{
        "response_type" => "code",
        "client_id" => client_id,
        "redirect_uri" => "http://localhost:3000/callback",
        "scope" => "openid profile",
        "state" => "client_state_123",
        "provider" => "google"
      }

      conn = get(conn, ~p"/oauth/authorize", params)

      # Should redirect directly to /auth/social/google/init
      assert redirected_to(conn) == "/auth/social/google/init"

      # Session should have the entire authorization_request preserved
      saved_request = get_session(conn, :authorization_request)
      assert saved_request != nil
      assert saved_request["client_id"] == client_id
      assert saved_request["state"] == "client_state_123"
    end

    test "supports connection parameter alias", %{conn: conn, client: client} do
      client_id = to_string(client.id)

      params = %{
        "response_type" => "code",
        "client_id" => client_id,
        "redirect_uri" => "http://localhost:3000/callback",
        "scope" => "openid profile",
        "connection" => "github"
      }

      conn = get(conn, ~p"/oauth/authorize", params)
      assert redirected_to(conn) == "/auth/social/github/init"
    end
  end
end
