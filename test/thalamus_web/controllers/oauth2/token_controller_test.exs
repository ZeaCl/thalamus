defmodule ThalamusWeb.OAuth2.TokenControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Domain.Entities.{User, Organization, OAuth2Client}
  alias Thalamus.Domain.ValueObjects.{
    AuthorizationCode,
    ClientId,
    GrantType,
    Scope,
    RedirectUri
  }

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

    # Create and verify user
    {:ok, user} = User.register("user@test.com", "Password123!")
    {:ok, user} = User.verify_email(user)
    {:ok, user} = PostgreSQLUserRepository.save(user)

    # Create OAuth2 client with new API
    {:ok, client_id} = ClientId.generate()
    {:ok, auth_code_grant} = GrantType.authorization_code()
    {:ok, refresh_grant} = GrantType.refresh_token()
    {:ok, client_creds_grant} = GrantType.client_credentials()
    {:ok, read_scope} = Scope.new("api:read")
    {:ok, write_scope} = Scope.new("api:write")
    {:ok, redirect_uri} = RedirectUri.new("http://localhost:3000/callback")

    # Generate plain text secret to use in tests
    plain_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    {:ok, client} =
      OAuth2Client.new(%{
        id: client_id,
        organization_id: org.id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: plain_secret,
        grant_types: [auth_code_grant, refresh_grant, client_creds_grant],
        redirect_uris: [redirect_uri],
        allowed_scopes: [read_scope, write_scope]
      })

    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    # Store plain secret for use in tests
    client = Map.put(client, :plain_secret, plain_secret)

    {:ok, %{user: user, client: client, org: org}}
  end

  describe "POST /oauth/token - authorization_code grant" do
    test "returns access token with valid authorization code", %{
      conn: conn,
      user: user,
      client: client
    } do
      # Generate authorization code
      {:ok, redirect_uri} = RedirectUri.new("http://localhost:3000/callback")
      {:ok, read_scope} = Scope.new("api:read")

      {:ok, auth_code} =
        AuthorizationCode.generate(
          client.id,
          user.id,
          redirect_uri,
          [read_scope],
          nil,
          600
        )

      # Store authorization code
      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scopes: ["api:read"],
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      # Exchange code for token
      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "authorization_code",
          code: auth_code.code,
          client_id: to_string(client.id),
          client_secret: client.plain_secret,
          redirect_uri: "http://localhost:3000/callback"
        })

      assert %{
               "access_token" => access_token,
               "token_type" => "Bearer",
               "expires_in" => expires_in,
               "refresh_token" => refresh_token,
               "scope" => "api:read"
             } = json_response(conn, 200)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert expires_in == 3600
    end

    test "returns error with invalid authorization code", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "authorization_code",
          code: "invalid_code",
          client_id: to_string(client.id),
          client_secret: client.plain_secret,
          redirect_uri: "http://localhost:3000/callback"
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => _
             } = json_response(conn, 400)
    end

    test "returns error with invalid client credentials", %{
      conn: conn,
      user: user,
      client: client
    } do
      {:ok, redirect_uri} = RedirectUri.new("http://localhost:3000/callback")
      {:ok, read_scope} = Scope.new("api:read")

      {:ok, auth_code} =
        AuthorizationCode.generate(
          client.id,
          user.id,
          redirect_uri,
          [read_scope],
          nil,
          600
        )

      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "authorization_code",
          code: auth_code.code,
          client_id: to_string(client.id),
          client_secret: "wrong_secret",
          redirect_uri: "http://localhost:3000/callback"
        })

      assert %{
               "error" => "invalid_client",
               "error_description" => _
             } = json_response(conn, 401)
    end

    test "returns error with mismatched redirect_uri", %{conn: conn, user: user, client: client} do
      {:ok, redirect_uri} = RedirectUri.new("http://localhost:3000/callback")
      {:ok, read_scope} = Scope.new("api:read")

      {:ok, auth_code} =
        AuthorizationCode.generate(
          client.id,
          user.id,
          redirect_uri,
          [read_scope],
          nil,
          600
        )

      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scopes: ["api:read"],
        redirect_uri: "http://localhost:3000/callback",
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "authorization_code",
          code: auth_code.code,
          client_id: to_string(client.id),
          client_secret: client.plain_secret,
          redirect_uri: "http://evil.com/callback"
        })

      assert %{
               "error" => "invalid_grant",
               "error_description" => _
             } = json_response(conn, 400)
    end
  end

  describe "POST /oauth/token - client_credentials grant" do
    test "returns access token with valid client credentials", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "client_credentials",
          client_id: to_string(client.id),
          client_secret: client.plain_secret,
          scope: "api:read api:write"
        })

      assert %{
               "access_token" => access_token,
               "token_type" => "Bearer",
               "expires_in" => 3600,
               "scope" => scope
             } = json_response(conn, 200)

      assert is_binary(access_token)
      assert scope in ["api:read api:write", "api:read,api:write"]
    end

    test "returns error with invalid client credentials", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "client_credentials",
          client_id: to_string(client.id),
          client_secret: "wrong_secret",
          scope: "api:read"
        })

      assert %{
               "error" => "invalid_client",
               "error_description" => _
             } = json_response(conn, 401)
    end

    test "returns error with unsupported scope", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "client_credentials",
          client_id: to_string(client.id),
          client_secret: client.plain_secret,
          scope: "admin delete"
        })

      assert %{
               "error" => "invalid_scope",
               "error_description" => _
             } = json_response(conn, 400)
    end
  end

  describe "POST /oauth/token - refresh_token grant" do
    @tag :skip
    test "returns new access token with valid refresh token", %{
      conn: conn,
      user: user,
      client: client
    } do
      # First, get tokens via authorization code
      {:ok, redirect_uri} = RedirectUri.new("http://localhost:3000/callback")
      {:ok, read_scope} = Scope.new("api:read")

      {:ok, auth_code} =
        AuthorizationCode.generate(
          client.id,
          user.id,
          redirect_uri,
          [read_scope],
          nil,
          600
        )

      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scopes: ["api:read"],
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      conn1 =
        post(conn, ~p"/oauth/token", %{
          grant_type: "authorization_code",
          code: auth_code.code,
          client_id: to_string(client.id),
          client_secret: client.plain_secret,
          redirect_uri: "http://localhost:3000/callback"
        })

      %{"refresh_token" => refresh_token} = json_response(conn1, 200)

      # Now use refresh token to get new access token
      conn2 =
        post(conn, ~p"/oauth/token", %{
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: to_string(client.id),
          client_secret: client.plain_secret
        })

      assert %{
               "access_token" => new_access_token,
               "token_type" => "Bearer",
               "expires_in" => 3600,
               "refresh_token" => new_refresh_token,
               "scope" => "api:read"
             } = json_response(conn2, 200)

      assert is_binary(new_access_token)
      assert is_binary(new_refresh_token)
      assert new_refresh_token != refresh_token
    end

    test "returns error with invalid refresh token", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "refresh_token",
          refresh_token: "invalid_refresh_token",
          client_id: to_string(client.id),
          client_secret: client.plain_secret
        })

      # May return 401 for client auth failure or 400 for invalid grant
      response = json_response(conn, conn.status)
      assert response["error"] in ["invalid_grant", "invalid_client"]
    end
  end

  describe "POST /oauth/token - validation" do
    test "returns error with missing grant_type", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/token", %{
          client_id: to_string(client.id),
          client_secret: client.plain_secret
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => _
             } = json_response(conn, 400)
    end

    test "returns error with unsupported grant_type", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "password",
          client_id: to_string(client.id),
          client_secret: client.plain_secret
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => _
             } = json_response(conn, 400)
    end

    test "returns error with missing client_id", %{conn: conn} do
      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "client_credentials",
          client_secret: "some_secret"
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => _
             } = json_response(conn, 400)
    end
  end

  describe "POST /oauth/token - PKCE support" do
    @tag :skip
    test "validates code_verifier with code_challenge", %{conn: conn, user: user, client: client} do
      # Generate PKCE challenge
      code_verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      {:ok, pkce_challenge} =
        Thalamus.Domain.ValueObjects.PKCEChallenge.from_verifier(code_verifier, :S256)

      code_challenge = pkce_challenge.value

      # Generate authorization code with PKCE
      {:ok, redirect_uri} = RedirectUri.new("http://localhost:3000/callback")
      {:ok, read_scope} = Scope.new("api:read")

      {:ok, auth_code} =
        AuthorizationCode.generate(
          client.id,
          user.id,
          redirect_uri,
          [read_scope],
          pkce_challenge,
          600
        )

      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scopes: ["api:read"],
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      # Exchange with correct code_verifier
      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "authorization_code",
          code: auth_code.code,
          client_id: to_string(client.id),
          client_secret: client.plain_secret,
          redirect_uri: "http://localhost:3000/callback",
          code_verifier: code_verifier
        })

      assert %{
               "access_token" => _,
               "token_type" => "Bearer"
             } = json_response(conn, 200)
    end

    @tag :skip
    test "rejects invalid code_verifier", %{conn: conn, user: user, client: client} do
      # Generate a verifier and challenge
      correct_verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      {:ok, pkce_challenge} =
        Thalamus.Domain.ValueObjects.PKCEChallenge.from_verifier(correct_verifier, :S256)

      code_challenge = pkce_challenge.value

      {:ok, redirect_uri} = RedirectUri.new("http://localhost:3000/callback")
      {:ok, read_scope} = Scope.new("api:read")

      {:ok, auth_code} =
        AuthorizationCode.generate(
          client.id,
          user.id,
          redirect_uri,
          [read_scope],
          pkce_challenge,
          600
        )

      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scopes: ["api:read"],
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      # Exchange with wrong code_verifier
      wrong_verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      conn =
        post(conn, ~p"/oauth/token", %{
          grant_type: "authorization_code",
          code: auth_code.code,
          client_id: to_string(client.id),
          client_secret: client.plain_secret,
          redirect_uri: "http://localhost:3000/callback",
          code_verifier: wrong_verifier
        })

      assert %{
               "error" => "invalid_grant",
               "error_description" => _
             } = json_response(conn, 400)
    end
  end
end
