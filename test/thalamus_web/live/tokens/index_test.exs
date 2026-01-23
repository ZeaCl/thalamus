defmodule ThalamusWeb.Tokens.IndexTest do
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
        "name" => "Test Org #{System.unique_integer()}",
        "plan_type" => "standard"
      })
      |> Repo.insert!()

    # Create an auth user
    auth_user = create_user(org, "admin@example.com", "Admin User")

    # Create a client for tokens
    client = create_oauth2_client(org, "Test Client")

    # Create a test user
    test_user = create_user(org, "user@example.com", "Test User")

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, auth_user.id)

    # Log in user for protected routes
    conn = log_in_user(conn)

    {:ok, conn: conn, conn: conn, org: org, user: test_user, client: client}
  end

  describe "Index LiveView" do
    test "mounts successfully and displays page title", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/tokens")

      assert html =~ "Tokens"
      assert has_element?(view, "h1", "Tokens")
    end

    test "displays list of tokens", %{conn: conn, user: user, client: client} do
      create_token(user, client, :access_token)
      create_token(user, client, :refresh_token)

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens")

      assert html =~ "Access Token"
      assert html =~ "Refresh Token"
    end

    test "filters by search query (user email)", %{
      conn: conn,
      user: user,
      client: client,
      org: org
    } do
      create_token(user, client, :access_token)

      other_user = create_user(org, "other@example.com", "Other User")
      create_token(other_user, client, :access_token)

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{search: "user@example.com"})

      assert html =~ "user@example.com"
      refute html =~ "other@example.com"
    end

    test "filters by search query (client name)", %{
      conn: conn,
      user: user,
      client: client,
      org: org
    } do
      create_token(user, client, :access_token)

      other_client = create_oauth2_client(org, "Other Client")
      create_token(user, other_client, :access_token)

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{search: "Test Client"})

      assert html =~ "Test Client"
      refute html =~ "Other Client"
    end

    test "filters by token type", %{conn: conn, user: user, client: client} do
      create_token(user, client, :access_token)
      create_token(user, client, :refresh_token)
      create_token(user, client, :authorization_code)

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      html =
        view
        |> element("form[phx-change='filter_type']")
        |> render_change(%{type: "access_token"})

      # Should show only 1 access token badge in the table (not in dropdown)
      access_token_count =
        html
        |> String.split("badge badge-primary badge-sm\">Access Token")
        |> length()
        |> Kernel.-(1)

      assert access_token_count == 1
    end

    test "filters by status - active", %{conn: conn, user: user, client: client} do
      # Create active token (expires in the future)
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_future = DateTime.add(now, 3600, :second)

      create_token(user, client, :access_token, expires_at: expires_future, revoked: false)

      # Create expired token
      expires_past = DateTime.add(now, -3600, :second)
      create_token(user, client, :access_token, expires_at: expires_past, revoked: false)

      # Create revoked token
      revoked_at = DateTime.add(now, -1800, :second)

      create_token(user, client, :access_token,
        expires_at: expires_future,
        revoked: true,
        revoked_at: revoked_at
      )

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      html =
        view
        |> element("form[phx-change='filter_status']")
        |> render_change(%{status: "active"})

      # Should show only 1 active token badge (not 2 or 3)
      active_count =
        html |> String.split("badge badge-success badge-sm\">Active") |> length() |> Kernel.-(1)

      assert active_count == 1
    end

    test "filters by status - expired", %{conn: conn, user: user, client: client} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Create expired token
      expires_past = DateTime.add(now, -3600, :second)
      create_token(user, client, :access_token, expires_at: expires_past, revoked: false)

      # Create active token
      expires_future = DateTime.add(now, 3600, :second)
      create_token(user, client, :access_token, expires_at: expires_future, revoked: false)

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      html =
        view
        |> element("form[phx-change='filter_status']")
        |> render_change(%{status: "expired"})

      # Should show only 1 expired token badge (not in dropdown)
      expired_count =
        html |> String.split("badge badge-warning badge-sm\">Expired") |> length() |> Kernel.-(1)

      assert expired_count == 1
    end

    test "filters by status - revoked", %{conn: conn, user: user, client: client} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_future = DateTime.add(now, 3600, :second)
      revoked_at = DateTime.add(now, -1800, :second)

      # Create revoked token
      create_token(user, client, :access_token,
        expires_at: expires_future,
        revoked: true,
        revoked_at: revoked_at
      )

      # Create active token
      create_token(user, client, :access_token, expires_at: expires_future, revoked: false)

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      html =
        view
        |> element("form[phx-change='filter_status']")
        |> render_change(%{status: "revoked"})

      # Should show only the revoked token
      assert html =~ "Revoked"
    end

    test "revokes token from list", %{conn: conn, user: user, client: client} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_future = DateTime.add(now, 3600, :second)

      token =
        create_token(user, client, :access_token, expires_at: expires_future, revoked: false)

      {:ok, view, html} = live(conn, ~p"/dashboard/tokens")

      assert html =~ "Active"

      view
      |> element("button[phx-click='revoke'][phx-value-id='#{token.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Revoked"

      updated = Repo.get(TokenSchema, token.id)
      assert updated.revoked == true
    end

    test "displays status badges correctly", %{conn: conn, user: user, client: client} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Active token
      create_token(user, client, :access_token,
        expires_at: DateTime.add(now, 3600, :second),
        revoked: false
      )

      # Expired token
      create_token(user, client, :refresh_token,
        expires_at: DateTime.add(now, -3600, :second),
        revoked: false
      )

      # Revoked token
      revoked_at = DateTime.add(now, -1800, :second)

      create_token(user, client, :authorization_code,
        expires_at: DateTime.add(now, 3600, :second),
        revoked: true,
        revoked_at: revoked_at
      )

      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens")

      assert html =~ "Active"
      assert html =~ "Expired"
      assert html =~ "Revoked"
    end

    test "displays user and client links", %{conn: conn, user: user, client: client} do
      create_token(user, client, :access_token)

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      assert has_element?(view, "a[href='/dashboard/users/#{user.id}']", user.email)
      assert has_element?(view, "a[href='/dashboard/clients/#{client.id}']", client.name)
    end

    test "displays empty state when no tokens", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/tokens")

      assert html =~ "No tokens found"
      assert html =~ "Tokens are created through OAuth2 flows"
    end

    test "provides navigation to token details", %{conn: conn, user: user, client: client} do
      token = create_token(user, client, :access_token)

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      assert has_element?(view, "a[href='/dashboard/tokens/#{token.id}']", "View")
    end

    test "does not show revoke button for already revoked tokens", %{
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

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      refute has_element?(view, "button[phx-click='revoke'][phx-value-id='#{token.id}']")
    end

    test "does not show revoke button for expired tokens", %{
      conn: conn,
      user: user,
      client: client
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_past = DateTime.add(now, -3600, :second)

      token = create_token(user, client, :access_token, expires_at: expires_past, revoked: false)

      {:ok, view, _html} = live(conn, ~p"/dashboard/tokens")

      refute has_element?(view, "button[phx-click='revoke'][phx-value-id='#{token.id}']")
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
