defmodule ThalamusWeb.OAuth2.DiscoveryControllerTest do
  use ThalamusWeb.ConnCase, async: false

  describe "GET /.well-known/openid-configuration" do
    test "returns OpenID Connect Discovery document", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      # REQUIRED fields per OpenID Connect Discovery 1.0
      assert Map.has_key?(response, "issuer")
      assert Map.has_key?(response, "authorization_endpoint")
      assert Map.has_key?(response, "token_endpoint")
      assert Map.has_key?(response, "response_types_supported")
      assert Map.has_key?(response, "subject_types_supported")
      assert Map.has_key?(response, "id_token_signing_alg_values_supported")
    end

    test "returns correct issuer URL", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # Issuer should be the base URL (http://localhost in tests)
      assert response["issuer"] == "http://www.example.com"
    end

    test "returns correct OAuth2 endpoints", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # Verify all OAuth2/OIDC endpoints are present
      assert response["authorization_endpoint"] == "http://www.example.com/oauth/authorize"
      assert response["token_endpoint"] == "http://www.example.com/oauth/token"
      assert response["userinfo_endpoint"] == "http://www.example.com/oauth/userinfo"
      assert response["introspection_endpoint"] == "http://www.example.com/oauth/introspect"
      assert response["revocation_endpoint"] == "http://www.example.com/oauth/revoke"
    end

    test "returns supported response types", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # Only authorization code flow supported (not implicit)
      assert response["response_types_supported"] == ["code"]
    end

    test "returns supported grant types", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # Authorization Code, Client Credentials, Refresh Token
      grant_types = response["grant_types_supported"]
      assert "authorization_code" in grant_types
      assert "client_credentials" in grant_types
      assert "refresh_token" in grant_types

      # Should NOT include password or implicit (deprecated/insecure)
      refute "password" in grant_types
      refute "implicit" in grant_types
    end

    test "returns supported scopes", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # Standard OIDC scopes
      scopes = response["scopes_supported"]
      assert "openid" in scopes
      assert "profile" in scopes
      assert "email" in scopes
      assert "address" in scopes
      assert "phone" in scopes
      assert "offline_access" in scopes
    end

    test "returns supported subject types", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # Only public subject type (not pairwise yet)
      assert response["subject_types_supported"] == ["public"]
    end

    test "returns supported signing algorithms", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # RS256 for JWT signing
      assert response["id_token_signing_alg_values_supported"] == ["RS256"]
    end

    test "returns supported token authentication methods", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # Client secret via Basic Auth or POST body
      auth_methods = response["token_endpoint_auth_methods_supported"]
      assert "client_secret_basic" in auth_methods
      assert "client_secret_post" in auth_methods
    end

    test "returns supported PKCE methods", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # S256 (SHA256) and plain
      pkce_methods = response["code_challenge_methods_supported"]
      assert "S256" in pkce_methods
      assert "plain" in pkce_methods
    end

    test "returns supported claims", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # Standard OIDC claims
      claims = response["claims_supported"]
      assert "sub" in claims
      assert "name" in claims
      assert "email" in claims
      assert "email_verified" in claims
    end

    test "returns supported response modes", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      response = json_response(conn, 200)

      # Query and fragment modes
      response_modes = response["response_modes_supported"]
      assert "query" in response_modes
      assert "fragment" in response_modes
    end

    test "returns valid JSON content type", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/openid-configuration")

      # Content-Type should be application/json
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end

    test "does not require authentication", %{conn: conn} do
      # Discovery endpoint should be publicly accessible
      conn = get(conn, ~p"/.well-known/openid-configuration")

      # Should succeed without authentication
      assert conn.status == 200
    end

    test "returns consistent data on multiple requests", %{conn: conn} do
      # First request
      conn1 = get(conn, ~p"/.well-known/openid-configuration")
      response1 = json_response(conn1, 200)

      # Second request
      conn2 = get(build_conn(), ~p"/.well-known/openid-configuration")
      response2 = json_response(conn2, 200)

      # Responses should be identical (discovery metadata is static)
      assert response1 == response2
    end
  end
end
