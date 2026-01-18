defmodule ThalamusWeb.OAuth2.IntrospectionControllerTest do
  use ThalamusWeb.ConnCase, async: true

  # TODO: Migrate to new OAuth2 token APIs
  @moduletag :skip

  alias Thalamus.Domain.Entities.{User, Organization, OAuth2Client}
  alias Thalamus.Domain.ValueObjects.AccessToken

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
    {:ok, client} =
      OAuth2Client.new(
        "Test Client",
        org.id,
        ["http://localhost:3000/callback"],
        [:authorization_code, :refresh_token, :client_credentials],
        [:read, :write]
      )

    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    {:ok, %{user: user, client: client, org: org}}
  end

  describe "POST /oauth/introspect" do
    test "returns active: true for valid access token", %{conn: conn, user: user, client: client} do
      # Generate access token
      {:ok, access_token} =
        AccessToken.generate(
          user.id,
          client.id,
          [:read, :write],
          3600
        )

      # Store token
      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scope: [:read, :write],
        expires_at: access_token.expires_at
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      # Introspect token with Basic Auth
      credentials = Base.encode64("#{client.id}:#{client.secret}")

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
      assert client_id == to_string(client.id)
      assert is_integer(exp)
      assert is_integer(iat)
    end

    test "returns active: false for invalid token", %{conn: conn, client: client} do
      credentials = Base.encode64("#{client.id}:#{client.secret}")

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

    test "returns active: false for expired token", %{conn: conn, user: user, client: client} do
      # Generate expired token (expires in the past)
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      {:ok, access_token} =
        AccessToken.generate(
          user.id,
          client.id,
          [:read],
          # Already expired
          -3600
        )

      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scope: [:read],
        expires_at: past_time
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      credentials = Base.encode64("#{client.id}:#{client.secret}")

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

    test "returns active: false for revoked token", %{conn: conn, user: user, client: client} do
      {:ok, access_token} = AccessToken.generate(user.id, client.id, [:read], 3600)

      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scope: [:read],
        expires_at: access_token.expires_at,
        revoked: true
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      credentials = Base.encode64("#{client.id}:#{client.secret}")

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

      assert json_response(conn, 401)
    end

    test "returns error with invalid client credentials", %{conn: conn, client: client} do
      credentials = Base.encode64("#{client.id}:wrong_secret")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/introspect", %{
          token: "some_token"
        })

      assert json_response(conn, 401)
    end

    test "returns error with missing token parameter", %{conn: conn, client: client} do
      credentials = Base.encode64("#{client.id}:#{client.secret}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> post(~p"/oauth/introspect", %{})

      assert %{
               "error" => "invalid_request"
             } = json_response(conn, 400)
    end

    test "includes user info for user tokens", %{conn: conn, user: user, client: client} do
      {:ok, access_token} = AccessToken.generate(user.id, client.id, [:read], 3600)

      token_data = %{
        token: access_token.token,
        type: :access_token,
        user_id: user.id,
        client_id: client.id,
        scope: [:read],
        expires_at: access_token.expires_at
      }

      :ok = PostgreSQLTokenRepository.store(token_data)

      credentials = Base.encode64("#{client.id}:#{client.secret}")

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

      assert sub == to_string(user.id)
    end
  end
end
