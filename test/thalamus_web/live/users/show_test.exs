defmodule ThalamusWeb.Users.ShowTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    UserSchema,
    OrganizationSchema,
    TokenSchema,
    OAuth2ClientSchema
  }

  setup %{conn: conn} do
    # Create test organization
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Test Organization",
        "plan_type" => "free"
      })
      |> Repo.insert!()

    # Create test OAuth2 client (required for tokens)
    client = create_test_client(org)

    # Create test user
    user = create_user(org, "testuser@example.com", "Test User", :active)

    # Create an authenticated user for session
    auth_user = create_user(org, "admin@example.com", "Admin User", :active)

    # Setup authenticated connection
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, auth_user.id)

    # Log in user for protected routes
    conn = log_in_user(conn)

    {:ok, conn: conn, conn: conn, org: org, user: user, auth_user: auth_user, client: client}
  end

  describe "Show LiveView" do
    test "mounts successfully and displays user details", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert html =~ "User Details"
      assert html =~ user.email
      assert has_element?(view, "h1", user.name)
    end

    test "displays user information", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert html =~ user.email
      assert html =~ user.name
      assert html =~ "Active"
    end

    test "displays organization name", %{conn: conn, user: user, org: org} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert html =~ org.name
    end

    test "displays 'No organization' for users without org", %{conn: conn, org: org} do
      user_no_org = create_user(nil, "noorg@example.com", "No Org User", :active)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user_no_org.id}")

      assert html =~ "No organization"
    end

    test "displays token statistics", %{conn: conn, user: user, client: client} do
      # Create some tokens for the user
      create_token(user, client, "access_token")
      create_token(user, client, "access_token", revoked: true)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      # Should show token stats
      assert html =~ "Total Tokens"
      assert html =~ "Active Tokens"
      assert html =~ "Revoked"
    end

    test "displays recent tokens", %{conn: conn, user: user, client: client} do
      # Create a token
      create_token(user, client, "access_token")

      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert html =~ "Recent Tokens"
      refute html =~ "No tokens issued yet"
    end

    test "displays empty state when no tokens exist", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert html =~ "No tokens issued yet"
    end

    test "displays verified status", %{conn: conn, user: user} do
      # Mark user as verified
      user
      |> UserSchema.verify_email_changeset()
      |> Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert html =~ "Yes"
    end

    test "displays unverified status", %{conn: conn, org: org} do
      unverified_user =
        create_user(org, "unverified@example.com", "Unverified", :pending_verification)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{unverified_user.id}")

      assert html =~ "No"
    end

    test "displays security information", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert html =~ "Security & MFA"
      assert html =~ "Failed Login Attempts"
    end

    test "displays MFA methods when configured", %{conn: conn, user: user} do
      # Add MFA method
      user
      |> UserSchema.update_changeset(%{
        mfa_methods: [
          %{"type" => "totp", "identifier" => "TOTP"}
        ]
      })
      |> Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert html =~ "totp"
      assert html =~ "TOTP"
    end

    test "displays 'No MFA methods' when not configured", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert html =~ "No MFA methods configured"
    end

    test "displays last login time", %{conn: conn, user: user} do
      # Update last login
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      user
      |> UserSchema.update_changeset(%{last_login_at: now})
      |> Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      # Should show the date (not "Never")
      refute html =~ "Never"
    end

    test "shows 'Never' when user has never logged in", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      # Last login should be "Never" for new users
      assert html =~ "Never"
    end
  end

  describe "User Actions" do
    test "allows verifying user email", %{conn: conn, org: org} do
      pending_user =
        create_user(org, "pending@example.com", "Pending User", :pending_verification)

      {:ok, view, html} = live(conn, ~p"/dashboard/users/#{pending_user.id}")

      # Verify Email button should be visible
      assert html =~ "Verify Email"

      # Click verify email
      html =
        view
        |> element("button[phx-click='verify_email']")
        |> render_click()

      # Should show verified status
      assert html =~ "Yes"
      assert html =~ "Active"

      # Verify status was changed in database
      updated_user = Repo.get(UserSchema, pending_user.id)
      assert updated_user.status == :active
      assert updated_user.verified_at
    end

    test "does not show verify button for already verified users", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      # Verify Email button should NOT be visible for active users
      refute html =~ "Verify Email"
    end

    test "allows resetting user password", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/#{user.id}")

      # Click reset password
      html =
        view
        |> element("button[phx-click='reset_password']")
        |> render_click()

      # Should display new password warning
      assert html =~ "New Password Generated!"
      assert html =~ "Please save this password securely"

      # Verify password was actually changed in database
      updated_user = Repo.get(UserSchema, user.id)
      refute updated_user.password_hash == user.password_hash
    end

    test "allows suspending active user", %{conn: conn, org: org} do
      # Create a fresh active user for this test
      active_user = create_user(org, "suspend@example.com", "Suspend User", :active)

      {:ok, view, html} = live(conn, ~p"/dashboard/users/#{active_user.id}")

      # Suspend button should be visible for active users
      assert html =~ "Suspend User"

      # Click suspend
      html =
        view
        |> element("button[phx-click='suspend']")
        |> render_click()

      # Should show suspended status
      assert html =~ "Suspended"
      assert html =~ "Reactivate User"

      # Verify status was changed in database
      updated_user = Repo.get(UserSchema, active_user.id)
      assert updated_user.status == :suspended
    end

    test "does not show suspend button for non-active users", %{conn: conn, org: org} do
      suspended_user = create_user(org, "suspended@example.com", "Suspended User", :suspended)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{suspended_user.id}")

      # Suspend button should NOT be visible
      refute html =~ "Suspend User"
    end

    test "allows reactivating suspended user", %{conn: conn, org: org} do
      suspended_user = create_user(org, "reactivate@example.com", "Reactivate User", :suspended)

      {:ok, view, html} = live(conn, ~p"/dashboard/users/#{suspended_user.id}")

      # Reactivate button should be visible for suspended users
      assert html =~ "Reactivate User"

      # Click reactivate
      html =
        view
        |> element("button[phx-click='reactivate']")
        |> render_click()

      # Should show active status
      assert html =~ "Active"
      assert html =~ "Suspend User"

      # Verify status was changed in database
      updated_user = Repo.get(UserSchema, suspended_user.id)
      assert updated_user.status == :active
    end

    test "does not show reactivate button for non-suspended users", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}")

      # Reactivate button should NOT be visible for active users
      refute html =~ "Reactivate User"
    end
  end

  describe "Navigation" do
    test "provides navigation back to users list", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert has_element?(view, "a[href='/dashboard/users']", "Back to Users")
    end

    test "provides navigation to edit user", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/#{user.id}")

      assert has_element?(view, "a[href='/dashboard/users/#{user.id}/edit']", "Edit")
    end

    test "redirects when user not found", %{conn: conn} do
      result = live(conn, ~p"/dashboard/users/#{Ecto.UUID.generate()}")

      assert {:error, {:live_redirect, %{to: "/dashboard/users"}}} = result
    end
  end

  # Helper functions
  defp create_user(org, email, name, status) do
    password_hash = Bcrypt.hash_pwd_salt("password123")

    attrs = %{
      email: email,
      name: name,
      password_hash: password_hash,
      status: status,
      organization_id: org && org.id
    }

    UserSchema.create_changeset(attrs)
    |> Repo.insert!()
  end

  defp create_test_client(org) do
    client_id = Ecto.UUID.generate()
    client_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    default_attrs = %{
      client_id_string: client_id,
      name: "Test Client",
      client_type: :confidential,
      client_secret: Bcrypt.hash_pwd_salt(client_secret),
      organization_id: org.id,
      allowed_grant_types: ["authorization_code"],
      allowed_scopes: ["openid", "profile"]
    }

    OAuth2ClientSchema.create_changeset(default_attrs)
    |> Repo.insert!()
  end

  defp create_token(user, client, type, attrs \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, 3600, :second)

    attrs_map = Enum.into(attrs, %{})
    revoked = Map.get(attrs_map, :revoked, false)

    %TokenSchema{
      token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      type: String.to_atom(type),
      user_id: user.id,
      client_id: client.id,
      scopes: ["openid", "profile"],
      expires_at: expires_at,
      revoked: revoked,
      inserted_at: now
    }
    |> Repo.insert!()
  end
end
