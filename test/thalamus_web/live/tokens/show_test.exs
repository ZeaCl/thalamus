defmodule ThalamusWeb.Tokens.ShowTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    TokenSchema,
    UserSchema,
    OAuth2ClientSchema,
    OrganizationSchema
  }

  setup %{conn: conn} do
    # Create an organization
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Test Org",
        "plan_type" => "professional"
      })
      |> Repo.insert!()

    # Create an auth user
    auth_user = create_user(org, "admin@example.com", "Admin User")

    # Create a client for tokens
    client = create_oauth2_client(org, "Test Client")

    # Create a test user
    test_user = create_user(org, "user@example.com", "Test User")

    # Create a test token
    token = create_token(test_user, client, :access_token)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, auth_user.id)

    # Log in user for protected routes
    conn = log_in_user(conn)

    {:ok, conn: conn, conn: conn, org: org, user: test_user, client: client, token: token}
  end

  describe "Show LiveView" do
    test "mounts successfully and displays token details", %{conn: conn, token: token} do
      {:ok, view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Token Details"
      assert has_element?(view, "h1", "Token Details")
    end

    test "displays token information", %{conn: conn, token: token} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ token.token
      assert html =~ "Access Token"
      assert html =~ "Active"
    end

    test "displays token type badge", %{conn: conn, token: token} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Access Token"
    end

    test "displays refresh token type", %{conn: conn, user: user, client: client} do
      token = create_token(user, client, :refresh_token)

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Refresh Token"
    end

    test "displays authorization code type", %{conn: conn, user: user, client: client} do
      token = create_token(user, client, :authorization_code)

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Authorization Code"
    end

    test "displays scopes", %{conn: conn, token: token} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "openid"
      assert html =~ "profile"
    end

    test "displays no scopes message when empty", %{conn: conn, user: user, client: client} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_at = DateTime.add(now, 3600, :second)

      token_value = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      token =
        %TokenSchema{
          token: token_value,
          type: :access_token,
          user_id: user.id,
          client_id: client.id,
          organization_id: user.organization_id,
          scopes: [],
          expires_at: expires_at,
          revoked: false,
          inserted_at: now
        }
        |> Repo.insert!()

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "No scopes"
    end

    test "displays expiration information", %{conn: conn, token: token} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Expires At"
    end

    test "shows active status for non-expired token", %{conn: conn, user: user, client: client} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_future = DateTime.add(now, 3600, :second)

      token =
        create_token(user, client, :access_token, expires_at: expires_future, revoked: false)

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Active"
    end

    test "shows expired status for expired token", %{conn: conn, user: user, client: client} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_past = DateTime.add(now, -3600, :second)

      token = create_token(user, client, :access_token, expires_at: expires_past, revoked: false)

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Expired"
    end

    test "shows revoked status for revoked token", %{conn: conn, user: user, client: client} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_future = DateTime.add(now, 3600, :second)
      revoked_at = DateTime.add(now, -1800, :second)

      token =
        create_token(user, client, :access_token,
          expires_at: expires_future,
          revoked: true,
          revoked_at: revoked_at
        )

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Revoked"
    end

    test "displays associated user information", %{conn: conn, token: token, user: user} do
      {:ok, view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ user.email
      assert html =~ user.name
      assert has_element?(view, "a[href='/dashboard/users/#{user.id}']", user.email)
    end

    test "displays associated client information", %{conn: conn, token: token, client: client} do
      {:ok, view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ client.name
      assert html =~ client.client_id_string
      assert has_element?(view, "a[href='/dashboard/clients/#{client.id}']", client.name)
    end

    test "displays PKCE information for authorization codes", %{
      conn: conn,
      user: user,
      client: client
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_at = DateTime.add(now, 600, :second)

      token_value = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      code_challenge = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      token =
        %TokenSchema{
          token: token_value,
          type: :authorization_code,
          user_id: user.id,
          client_id: client.id,
          organization_id: user.organization_id,
          scopes: ["openid"],
          expires_at: expires_at,
          revoked: false,
          code_challenge: code_challenge,
          code_challenge_method: "S256",
          inserted_at: now
        }
        |> Repo.insert!()

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "PKCE Details"
      assert html =~ code_challenge
      assert html =~ "S256"
    end

    test "does not display PKCE section for access tokens", %{conn: conn, token: token} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      refute html =~ "PKCE Details"
    end

    test "allows revoking an active token", %{conn: conn, user: user, client: client} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_future = DateTime.add(now, 3600, :second)

      token =
        create_token(user, client, :access_token, expires_at: expires_future, revoked: false)

      {:ok, view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Revoke Token"

      view
      |> element("button[phx-click='revoke']")
      |> render_click()

      # Reload the view to get updated HTML
      html = render(view)
      assert html =~ "Revoked"

      updated = Repo.get(TokenSchema, token.id)
      assert updated.revoked == true
      assert updated.revoked_at != nil
    end

    test "does not show revoke button for already revoked token", %{
      conn: conn,
      user: user,
      client: client
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_future = DateTime.add(now, 3600, :second)
      revoked_at = DateTime.add(now, -1800, :second)

      token =
        create_token(user, client, :access_token,
          expires_at: expires_future,
          revoked: true,
          revoked_at: revoked_at
        )

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      refute has_element?(view, "button[phx-click='revoke']")
    end

    test "does not show revoke button for expired token", %{
      conn: conn,
      user: user,
      client: client
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_past = DateTime.add(now, -3600, :second)

      token = create_token(user, client, :access_token, expires_at: expires_past, revoked: false)

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      refute has_element?(view, "button[phx-click='revoke']")
    end

    test "displays revoked_at timestamp for revoked tokens", %{
      conn: conn,
      user: user,
      client: client
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_future = DateTime.add(now, 3600, :second)
      revoked_at = DateTime.add(now, -1800, :second)

      token_value = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      token =
        %TokenSchema{
          token: token_value,
          type: :access_token,
          user_id: user.id,
          client_id: client.id,
          organization_id: user.organization_id,
          scopes: ["openid"],
          expires_at: expires_future,
          revoked: true,
          revoked_at: revoked_at,
          inserted_at: now
        }
        |> Repo.insert!()

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert html =~ "Revoked At"
    end

    test "provides navigation back to tokens list", %{conn: conn, token: token} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens/#{token.id}")

      assert has_element?(view, "a[href='/dashboard/tokens']", "Back to Tokens")
    end

    test "redirects when token not found", %{conn: conn} do
      result = live(conn, ~p"/dashboard/tokens/#{Ecto.UUID.generate()}")

      assert {:error, {:live_redirect, %{to: "/dashboard/tokens"}}} = result
    end
  end

  # Helper functions

  defp create_user(org, email, name) do
    password_hash = Bcrypt.hash_pwd_salt("password123")

    UserSchema.create_changeset(%{
      email: email,
      name: name,
      password_hash: password_hash,
      status: :active,
      organization_id: org.id
    })
    |> Repo.insert!()
  end

  defp create_oauth2_client(org, name) do
    client_id = Ecto.UUID.generate()
    client_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    OAuth2ClientSchema.create_changeset(%{
      client_id_string: client_id,
      name: name,
      client_type: :confidential,
      client_secret: Bcrypt.hash_pwd_salt(client_secret),
      organization_id: org.id,
      allowed_grant_types: ["authorization_code", "client_credentials"],
      allowed_scopes: ["openid", "profile"]
    })
    |> Repo.insert!()
  end

  defp create_token(user, client, type, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = Keyword.get(opts, :expires_at, DateTime.add(now, 3600, :second))
    revoked = Keyword.get(opts, :revoked, false)
    revoked_at = Keyword.get(opts, :revoked_at)

    token_value = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    %TokenSchema{
      token: token_value,
      type: type,
      user_id: user.id,
      client_id: client.id,
      organization_id: user.organization_id,
      scopes: ["openid", "profile"],
      expires_at: expires_at,
      revoked: revoked,
      revoked_at: revoked_at,
      inserted_at: now
    }
    |> Repo.insert!()
  end
end
