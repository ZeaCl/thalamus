defmodule ThalamusWeb.OAuth2.TokenControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.{User, Organization, OAuth2Client}
  alias Thalamus.Domain.ValueObjects.{AuthorizationCode, RefreshToken}
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

    # Create OAuth2 client
    {:ok, client} = OAuth2Client.new(
      "Test Client",
      org.id,
      ["http://localhost:3000/callback"],
      [:authorization_code, :refresh_token, :client_credentials],
      [:read, :write]
    )
    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    {:ok, %{user: user, client: client, org: org}}
  end

  describe "POST /oauth/token - authorization_code grant" do
    test "returns access token with valid authorization code", %{conn: conn, user: user, client: client} do
      # Generate authorization code
      {:ok, auth_code} = AuthorizationCode.generate(
        client.id,
        user.id,
        {:ok, redirect_uri} = Thalamus.Domain.ValueObjects.RedirectURI.new("http://localhost:3000/callback"),
        [:read],
        nil,
        600
      )

      # Store authorization code
      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scope: [:read],
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }
      :ok = PostgreSQLTokenRepository.store(token_data)

      # Exchange code for token
      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "authorization_code",
        code: auth_code.code,
        client_id: to_string(client.id),
        client_secret: client.secret,
        redirect_uri: "http://localhost:3000/callback"
      })

      assert %{
        "access_token" => access_token,
        "token_type" => "Bearer",
        "expires_in" => expires_in,
        "refresh_token" => refresh_token,
        "scope" => "read"
      } = json_response(conn, 200)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert expires_in == 3600
    end

    test "returns error with invalid authorization code", %{conn: conn, client: client} do
      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "authorization_code",
        code: "invalid_code",
        client_id: to_string(client.id),
        client_secret: client.secret,
        redirect_uri: "http://localhost:3000/callback"
      })

      assert %{
        "error" => "invalid_grant",
        "error_description" => _
      } = json_response(conn, 400)
    end

    test "returns error with invalid client credentials", %{conn: conn, user: user, client: client} do
      {:ok, auth_code} = AuthorizationCode.generate(
        client.id,
        user.id,
        {:ok, redirect_uri} = Thalamus.Domain.ValueObjects.RedirectURI.new("http://localhost:3000/callback"),
        [:read],
        nil,
        600
      )

      conn = post(conn, ~p"/oauth/token", %{
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
      {:ok, auth_code} = AuthorizationCode.generate(
        client.id,
        user.id,
        {:ok, redirect_uri} = Thalamus.Domain.ValueObjects.RedirectURI.new("http://localhost:3000/callback"),
        [:read],
        nil,
        600
      )

      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scope: [:read],
        redirect_uri: "http://localhost:3000/callback",
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }
      :ok = PostgreSQLTokenRepository.store(token_data)

      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "authorization_code",
        code: auth_code.code,
        client_id: to_string(client.id),
        client_secret: client.secret,
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
      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "client_credentials",
        client_id: to_string(client.id),
        client_secret: client.secret,
        scope: "read write"
      })

      assert %{
        "access_token" => access_token,
        "token_type" => "Bearer",
        "expires_in" => 3600,
        "scope" => scope
      } = json_response(conn, 200)

      assert is_binary(access_token)
      assert scope in ["read write", "read,write"]
    end

    test "returns error with invalid client credentials", %{conn: conn, client: client} do
      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "client_credentials",
        client_id: to_string(client.id),
        client_secret: "wrong_secret",
        scope: "read"
      })

      assert %{
        "error" => "invalid_client",
        "error_description" => _
      } = json_response(conn, 401)
    end

    test "returns error with unsupported scope", %{conn: conn, client: client} do
      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "client_credentials",
        client_id: to_string(client.id),
        client_secret: client.secret,
        scope: "admin delete"
      })

      assert %{
        "error" => "invalid_scope",
        "error_description" => _
      } = json_response(conn, 400)
    end
  end

  describe "POST /oauth/token - refresh_token grant" do
    test "returns new access token with valid refresh token", %{conn: conn, user: user, client: client} do
      # First, get tokens via authorization code
      {:ok, auth_code} = AuthorizationCode.generate(
        client.id,
        user.id,
        {:ok, redirect_uri} = Thalamus.Domain.ValueObjects.RedirectURI.new("http://localhost:3000/callback"),
        [:read],
        nil,
        600
      )

      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scope: [:read],
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }
      :ok = PostgreSQLTokenRepository.store(token_data)

      conn1 = post(conn, ~p"/oauth/token", %{
        grant_type: "authorization_code",
        code: auth_code.code,
        client_id: to_string(client.id),
        client_secret: client.secret,
        redirect_uri: "http://localhost:3000/callback"
      })

      %{"refresh_token" => refresh_token} = json_response(conn1, 200)

      # Now use refresh token to get new access token
      conn2 = post(conn, ~p"/oauth/token", %{
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: to_string(client.id),
        client_secret: client.secret
      })

      assert %{
        "access_token" => new_access_token,
        "token_type" => "Bearer",
        "expires_in" => 3600,
        "refresh_token" => new_refresh_token,
        "scope" => "read"
      } = json_response(conn2, 200)

      assert is_binary(new_access_token)
      assert is_binary(new_refresh_token)
      assert new_refresh_token != refresh_token
    end

    test "returns error with invalid refresh token", %{conn: conn, client: client} do
      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "refresh_token",
        refresh_token: "invalid_refresh_token",
        client_id: to_string(client.id),
        client_secret: client.secret
      })

      assert %{
        "error" => "invalid_grant",
        "error_description" => _
      } = json_response(conn, 400)
    end
  end

  describe "POST /oauth/token - validation" do
    test "returns error with missing grant_type", %{conn: conn, client: client} do
      conn = post(conn, ~p"/oauth/token", %{
        client_id: to_string(client.id),
        client_secret: client.secret
      })

      assert %{
        "error" => "invalid_request",
        "error_description" => _
      } = json_response(conn, 400)
    end

    test "returns error with unsupported grant_type", %{conn: conn, client: client} do
      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "password",
        client_id: to_string(client.id),
        client_secret: client.secret
      })

      assert %{
        "error" => "unsupported_grant_type",
        "error_description" => _
      } = json_response(conn, 400)
    end

    test "returns error with missing client_id", %{conn: conn} do
      conn = post(conn, ~p"/oauth/token", %{
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
    test "validates code_verifier with code_challenge", %{conn: conn, user: user, client: client} do
      # Generate PKCE challenge
      code_verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      code_challenge = :crypto.hash(:sha256, code_verifier) |> Base.url_encode64(padding: false)

      {:ok, pkce_challenge} = Thalamus.Domain.ValueObjects.PKCEChallenge.new(code_challenge, :S256)

      # Generate authorization code with PKCE
      {:ok, auth_code} = AuthorizationCode.generate(
        client.id,
        user.id,
        {:ok, redirect_uri} = Thalamus.Domain.ValueObjects.RedirectURI.new("http://localhost:3000/callback"),
        [:read],
        pkce_challenge,
        600
      )

      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scope: [:read],
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }
      :ok = PostgreSQLTokenRepository.store(token_data)

      # Exchange with correct code_verifier
      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "authorization_code",
        code: auth_code.code,
        client_id: to_string(client.id),
        client_secret: client.secret,
        redirect_uri: "http://localhost:3000/callback",
        code_verifier: code_verifier
      })

      assert %{
        "access_token" => _,
        "token_type" => "Bearer"
      } = json_response(conn, 200)
    end

    test "rejects invalid code_verifier", %{conn: conn, user: user, client: client} do
      code_challenge = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      {:ok, pkce_challenge} = Thalamus.Domain.ValueObjects.PKCEChallenge.new(code_challenge, :S256)

      {:ok, auth_code} = AuthorizationCode.generate(
        client.id,
        user.id,
        {:ok, redirect_uri} = Thalamus.Domain.ValueObjects.RedirectURI.new("http://localhost:3000/callback"),
        [:read],
        pkce_challenge,
        600
      )

      token_data = %{
        token: auth_code.code,
        type: :authorization_code,
        user_id: user.id,
        client_id: client.id,
        scope: [:read],
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      }
      :ok = PostgreSQLTokenRepository.store(token_data)

      # Exchange with wrong code_verifier
      wrong_verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      conn = post(conn, ~p"/oauth/token", %{
        grant_type: "authorization_code",
        code: auth_code.code,
        client_id: to_string(client.id),
        client_secret: client.secret,
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
