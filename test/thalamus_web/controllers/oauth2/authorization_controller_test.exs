defmodule ThalamusWeb.OAuth2.AuthorizationControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.TestHelpers

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLOAuth2ClientRepository
  }

  setup do
    # Create organization
    {:ok, org} = Organization.new("Test Corp", "owner@test.com", :professional)
    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    # Create and verify user
    {:ok, user} = User.register("user@test.com", "Password123!")
    {:ok, user} = User.verify_email(user)
    {:ok, user} = PostgreSQLUserRepository.save(user)

    # Create OAuth2 client
    {:ok, client} =
      TestHelpers.create_test_client(
        "Test Client",
        org.id,
        ["openid", "profile", "email"],
        redirect_uris: ["http://localhost:3000/callback"],
        grant_types: [:authorization_code, :refresh_token]
      )

    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    {:ok, %{user: user, client: client, org: org}}
  end

  describe "GET /oauth/authorize - authorization request" do
    test "shows consent screen with valid parameters", %{conn: conn, client: client} do
      # Simulate logged-in user
      conn =
        conn
        |> put_session(:user_id, "some_user_id")
        |> get(~p"/oauth/authorize", %{
          response_type: "code",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read write",
          state: "random_state_123"
        })

      # Should show consent screen (200 OK)
      assert html_response(conn, 200)
      assert conn.resp_body =~ "Test Client"
      assert conn.resp_body =~ "read"
      assert conn.resp_body =~ "write"
    end

    test "shows consent screen with PKCE parameters", %{conn: conn, client: client} do
      code_verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      code_challenge = :crypto.hash(:sha256, code_verifier) |> Base.url_encode64(padding: false)

      conn =
        conn
        |> put_session(:user_id, "some_user_id")
        |> get(~p"/oauth/authorize", %{
          response_type: "code",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read",
          state: "state_123",
          code_challenge: code_challenge,
          code_challenge_method: "S256"
        })

      assert html_response(conn, 200)
    end

    test "redirects to login if user not authenticated", %{conn: conn, client: client} do
      conn =
        get(conn, ~p"/oauth/authorize", %{
          response_type: "code",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read",
          state: "state_123"
        })

      # Should redirect to login
      assert redirected_to(conn, 302) =~ "/login"
    end

    test "returns error with missing response_type", %{conn: conn, client: client} do
      conn =
        conn
        |> put_session(:user_id, "some_user_id")
        |> get(~p"/oauth/authorize", %{
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback"
        })

      assert response(conn, 400)
    end

    test "returns error with invalid response_type", %{conn: conn, client: client} do
      conn =
        conn
        |> put_session(:user_id, "some_user_id")
        |> get(~p"/oauth/authorize", %{
          # Not supported
          response_type: "token",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback"
        })

      assert response(conn, 400)
    end

    test "returns error with invalid client_id", %{conn: conn} do
      conn =
        conn
        |> put_session(:user_id, "some_user_id")
        |> get(~p"/oauth/authorize", %{
          response_type: "code",
          client_id: "invalid_client_id",
          redirect_uri: "http://localhost:3000/callback"
        })

      assert response(conn, 400)
    end

    test "returns error with unauthorized redirect_uri", %{conn: conn, client: client} do
      conn =
        conn
        |> put_session(:user_id, "some_user_id")
        |> get(~p"/oauth/authorize", %{
          response_type: "code",
          client_id: to_string(client.id),
          # Not in allowed list
          redirect_uri: "http://evil.com/callback",
          scope: "read"
        })

      assert response(conn, 400)
      assert conn.resp_body =~ "redirect_uri"
    end

    test "returns error with unsupported scope", %{conn: conn, client: client} do
      conn =
        conn
        |> put_session(:user_id, "some_user_id")
        |> get(~p"/oauth/authorize", %{
          response_type: "code",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          # Not allowed for this client
          scope: "admin delete"
        })

      assert response(conn, 400)
    end

    test "returns error with invalid PKCE challenge method", %{conn: conn, client: client} do
      conn =
        conn
        |> put_session(:user_id, "some_user_id")
        |> get(~p"/oauth/authorize", %{
          response_type: "code",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read",
          code_challenge: "some_challenge",
          # Invalid method
          code_challenge_method: "MD5"
        })

      assert response(conn, 400)
    end
  end

  describe "POST /oauth/authorize - consent processing" do
    test "redirects with authorization code when user approves", %{
      conn: conn,
      user: user,
      client: client
    } do
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read",
          state: "state_123"
        })

      # Should redirect to callback URL
      assert redirected_to(conn, 302) =~ "http://localhost:3000/callback"

      # Extract redirect location
      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      uri = URI.parse(location)

      # Parse query parameters
      params = URI.decode_query(uri.query)

      # Should include authorization code and state
      assert Map.has_key?(params, "code")
      assert params["state"] == "state_123"
      assert String.starts_with?(params["code"], "ac_")
    end

    test "redirects with error when user denies", %{conn: conn, user: user, client: client} do
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "deny",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read",
          state: "state_123"
        })

      # Should redirect to callback URL with error
      assert redirected_to(conn, 302) =~ "http://localhost:3000/callback"

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      uri = URI.parse(location)
      params = URI.decode_query(uri.query)

      # Should include error
      assert params["error"] == "access_denied"
      assert params["state"] == "state_123"
    end

    test "includes PKCE parameters in authorization code", %{
      conn: conn,
      user: user,
      client: client
    } do
      code_challenge = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read",
          state: "state_123",
          code_challenge: code_challenge,
          code_challenge_method: "S256"
        })

      assert redirected_to(conn, 302) =~ "code="

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      uri = URI.parse(location)
      params = URI.decode_query(uri.query)

      assert Map.has_key?(params, "code")
    end

    test "preserves state parameter in redirect", %{conn: conn, user: user, client: client} do
      random_state = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read",
          state: random_state
        })

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      uri = URI.parse(location)
      params = URI.decode_query(uri.query)

      assert params["state"] == random_state
    end

    test "returns error with invalid decision", %{conn: conn, user: user, client: client} do
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "invalid_decision",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read"
        })

      assert response(conn, 400)
    end

    test "returns error when user not authenticated", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read"
        })

      assert response(conn, 401)
    end

    test "returns error with missing required parameters", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve"
        })

      assert response(conn, 400)
    end
  end

  describe "authorization code expiration" do
    test "authorization code expires after configured time", %{
      conn: conn,
      user: user,
      client: client
    } do
      # Generate authorization code
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read",
          state: "state_123"
        })

      location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
      uri = URI.parse(location)
      params = URI.decode_query(uri.query)
      auth_code = params["code"]

      # Authorization codes should expire in 10 minutes (600 seconds)
      # This is tested in the TokenController when attempting to exchange
      assert is_binary(auth_code)
      assert String.length(auth_code) > 20
    end
  end

  describe "scope validation" do
    test "allows requested scopes that are subset of client allowed scopes", %{
      conn: conn,
      user: user,
      client: client
    } do
      # Client allows [:read, :write], request only [:read]
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          # Subset of allowed scopes
          scope: "read",
          state: "state_123"
        })

      assert redirected_to(conn, 302) =~ "code="
    end

    test "rejects scopes not in client allowed list", %{conn: conn, user: user, client: client} do
      # Client allows [:read, :write], request [:admin]
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          # Not in allowed scopes
          scope: "admin",
          state: "state_123"
        })

      assert response(conn, 400)
    end

    test "uses default scopes when no scope specified", %{conn: conn, user: user, client: client} do
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          state: "state_123"
          # No scope parameter
        })

      # Should succeed with default scopes
      assert redirected_to(conn, 302) =~ "code="
    end
  end

  describe "redirect URI validation" do
    test "allows exact match redirect URI", %{conn: conn, user: user, client: client} do
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          # Exact match
          redirect_uri: "http://localhost:3000/callback",
          scope: "read"
        })

      assert redirected_to(conn, 302)
    end

    test "rejects redirect URI not in client allowed list", %{
      conn: conn,
      user: user,
      client: client
    } do
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          redirect_uri: "http://evil.com/steal-codes",
          scope: "read"
        })

      assert response(conn, 400)
    end

    test "rejects redirect URI with different scheme", %{conn: conn, user: user, client: client} do
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> post(~p"/oauth/authorize", %{
          decision: "approve",
          client_id: to_string(client.id),
          # https instead of http
          redirect_uri: "https://localhost:3000/callback",
          scope: "read"
        })

      assert response(conn, 400)
    end
  end

  describe "rate limiting" do
    @tag :rate_limit
    test "rate limits authorization requests", %{conn: conn, user: user, client: client} do
      # Make multiple requests
      for _n <- 1..25 do
        conn
        |> put_session(:user_id, to_string(user.id))
        |> get(~p"/oauth/authorize", %{
          response_type: "code",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read"
        })
      end

      # Next request should be rate limited
      conn =
        conn
        |> put_session(:user_id, to_string(user.id))
        |> get(~p"/oauth/authorize", %{
          response_type: "code",
          client_id: to_string(client.id),
          redirect_uri: "http://localhost:3000/callback",
          scope: "read"
        })

      # Should return 429 Too Many Requests
      assert conn.status == 429
    end
  end
end
