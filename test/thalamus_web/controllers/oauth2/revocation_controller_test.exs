defmodule ThalamusWeb.OAuth2.RevocationControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Entities.{User, Organization, OAuth2Client}
  alias Thalamus.Domain.ValueObjects.{AccessToken, ClientId, GrantType, Scope, RedirectUri}

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
    {:ok, write_scope} = Scope.new("zea:write")
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

  describe "POST /oauth/revoke" do
    @tag :skip
    test "revokes valid access token", %{conn: conn, user: user, client: client} do
      # Generate access token
      {:ok, read_scope} = Scope.new("api:read")
      {:ok, access_token} = AccessToken.generate([read_scope], user.id, 3600)

      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scopes: ["api:read"],
        expires_at: access_token.expires_at
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      # Revoke token
      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/revoke", %{
          token: access_token.token,
          token_type_hint: "access_token"
        })

      # Per RFC 7009, always returns 200 OK
      assert response(conn, 200)

      # Verify token is revoked
      {:ok, revoked_token} = PostgreSQLTokenRepository.find(access_token.token)
      assert revoked_token.revoked == true
    end

    @tag :skip
    test "revokes valid refresh token", %{conn: conn, user: user, client: client} do
      {:ok, refresh_token} = RefreshToken.generate(user.id, client.id, [:read, :write])

      token_data = %{
        token: refresh_token.token,
        type: :refresh_token,
        user_id: user.id,
        client_id: client.id,
        scope: [:read, :write],
        expires_at: DateTime.add(DateTime.utc_now(), 2_592_000, :second)
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/revoke", %{
          token: refresh_token.token,
          token_type_hint: "refresh_token"
        })

      assert response(conn, 200)
    end

    @tag :skip
    test "returns 200 for invalid token (per RFC 7009)", %{conn: conn, client: client} do
      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/revoke", %{
          token: "invalid_nonexistent_token"
        })

      # Per RFC 7009, MUST return 200 even for invalid tokens
      # This prevents information leakage
      assert response(conn, 200)
    end

    @tag :skip
    test "returns 200 for already revoked token", %{conn: conn, user: user, client: client} do
      {:ok, read_scope} = Scope.new("api:read")
      {:ok, access_token} = AccessToken.generate([read_scope], user.id, 3600)

      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scopes: ["api:read"],
        expires_at: access_token.expires_at,
        revoked: true
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/revoke", %{
          token: access_token.token
        })

      assert response(conn, 200)
    end

    @tag :skip
    test "returns error with missing client credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/oauth/revoke", %{
          token: "some_token"
        })

      assert json_response(conn, 401)
    end

    @tag :skip
    test "returns error with invalid client credentials", %{conn: conn, client: client} do
      credentials = Base.encode64("#{client.id}:wrong_secret")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/revoke", %{
          token: "some_token"
        })

      assert json_response(conn, 401)
    end

    @tag :skip
    test "returns error with missing token parameter", %{conn: conn, client: client} do
      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/revoke", %{})

      assert %{
               "error" => "invalid_request"
             } = json_response(conn, 400)
    end

    @tag :skip
    test "client can only revoke its own tokens", %{conn: conn, user: user, client: client} do
      # Create another client
      {:ok, other_client_id} = ClientId.generate()
      {:ok, client_creds_grant} = GrantType.client_credentials()
      {:ok, read_scope} = Scope.new("api:read")
      {:ok, redirect_uri} = RedirectUri.new("http://other.com/callback")

      other_plain_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      {:ok, other_client} =
        OAuth2Client.new(%{
          id: other_client_id,
          organization_id: client.organization_id,
          name: "Other Client",
          client_type: :confidential,
          client_secret: other_plain_secret,
          grant_types: [client_creds_grant],
          redirect_uris: [redirect_uri],
          allowed_scopes: [read_scope]
        })

      {:ok, other_client} = PostgreSQLOAuth2ClientRepository.save(other_client)

      # Create token for first client
      {:ok, read_scope} = Scope.new("api:read")
      {:ok, access_token} = AccessToken.generate([read_scope], user.id, 3600)

      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scopes: ["api:read"],
        expires_at: access_token.expires_at
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      # Try to revoke with other client's credentials
      credentials = Base.encode64("#{other_client.id}:#{other_plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/revoke", %{
          token: access_token.token
        })

      # Should still return 200 per RFC 7009 (no information leakage)
      assert response(conn, 200)

      # But token should NOT be revoked
      {:ok, token} = PostgreSQLTokenRepository.find(access_token.token)
      refute token.revoked
    end
  end
end
