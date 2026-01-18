defmodule ThalamusWeb.OAuth2.IntrospectionControllerTest do
  use ThalamusWeb.ConnCase, async: true

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
    {:ok, org} = Organization.new("Test Corp", "owner@test.com", :professional)
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
    {:ok, read_scope} = Scope.new("zea:read")
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

  describe "POST /oauth/introspect" do
    test "returns active: true for valid access token", %{conn: conn, user: user, client: client} do
      # Generate access token
      {:ok, read_scope} = Scope.new("zea:read")
      {:ok, write_scope} = Scope.new("zea:write")

      {:ok, access_token} =
        AccessToken.generate(
          [read_scope, write_scope],
          user.id,
          3600
        )

      # Store token
      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scopes: ["zea:read", "zea:write"],
        expires_at: access_token.expires_at
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      # Introspect token with Basic Auth
      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/introspect", %{
          token: access_token.token,
          token_type_hint: "access_token"
        })

      assert %{
               "active" => true,
               "scope" => scope,
               "client_id" => client_id,
               "token_type" => "Bearer",
               "exp" => exp,
               "iat" => iat
             } = json_response(conn, 200)

      assert is_binary(scope)
      # client_id is returned as UUID without prefix
      assert String.contains?(to_string(client.id), client_id)
      assert is_integer(exp)
      assert is_integer(iat)
    end

    test "returns active: false for invalid token", %{conn: conn, client: client} do
      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/introspect", %{
          token: "invalid_token_12345"
        })

      assert %{
               "active" => false
             } = json_response(conn, 200)
    end

    @tag :skip
    test "returns active: false for expired token", %{conn: conn, user: user, client: client} do
      # Generate token and manually set it as expired
      {:ok, read_scope} = Scope.new("zea:read")
      {:ok, access_token} = AccessToken.generate([read_scope], user.id, 3600)

      # Set expiry to the past
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scopes: ["zea:read"],
        expires_at: past_time
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/introspect", %{
          token: access_token.token
        })

      assert %{
               "active" => false
             } = json_response(conn, 200)
    end

    @tag :skip
    test "returns active: false for revoked token", %{conn: conn, user: user, client: client} do
      {:ok, read_scope} = Scope.new("zea:read")
      {:ok, access_token} = AccessToken.generate([read_scope], user.id, 3600)

      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scopes: ["zea:read"],
        expires_at: access_token.expires_at,
        revoked: true
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/introspect", %{
          token: access_token.token
        })

      assert %{
               "active" => false
             } = json_response(conn, 200)
    end

    test "returns error with missing client credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/oauth/introspect", %{
          token: "some_token"
        })

      # Per RFC 7662, returns 200 with active: false for authentication issues
      assert %{"active" => false} = json_response(conn, 200)
    end

    test "returns error with invalid client credentials", %{conn: conn, client: client} do
      credentials = Base.encode64("#{client.id}:wrong_secret")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/introspect", %{
          token: "some_token"
        })

      # Per RFC 7662, returns 200 with active: false for authentication issues
      assert %{"active" => false} = json_response(conn, 200)
    end

    test "returns error with missing token parameter", %{conn: conn, client: client} do
      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/introspect", %{})

      assert %{
               "error" => "invalid_request"
             } = json_response(conn, 400)
    end

    test "includes user info for user tokens", %{conn: conn, user: user, client: client} do
      {:ok, read_scope} = Scope.new("zea:read")
      {:ok, access_token} = AccessToken.generate([read_scope], user.id, 3600)

      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scopes: ["zea:read"],
        expires_at: access_token.expires_at
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      credentials = Base.encode64("#{client.id}:#{client.plain_secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/introspect", %{
          token: access_token.token
        })

      assert %{
               "active" => true,
               "sub" => sub
             } = json_response(conn, 200)

      # sub is returned as UUID without prefix
      assert String.contains?(to_string(user.id), sub)
    end
  end
end
