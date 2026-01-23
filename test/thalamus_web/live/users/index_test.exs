defmodule ThalamusWeb.Users.IndexTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OrganizationSchema}

  setup %{conn: conn} do
    # Create test organization
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Test Org #{System.unique_integer()}",
        "plan_type" => "free"
      })
      |> Repo.insert!()

    # Create an authenticated user for session
    auth_user = create_user(org, "admin@example.com", "Admin User", :active)

    # Log in user for protected routes (loads user into session and assigns)
    conn = log_in_user(conn, auth_user.id)

    {:ok, conn: conn, org: org, auth_user: auth_user}
  end

  describe "Index LiveView" do
    test "mounts successfully and displays page title", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/users")

      assert html =~ "Users"
      assert has_element?(view, "h1", "Users")
      assert html =~ "Manage user accounts and permissions"
    end

    test "displays empty state when no users exist (except auth user)", %{
      conn: conn,
      auth_user: auth_user
    } do
      # Clean up any existing users except the authenticated one
      UserSchema
      |> Repo.all()
      |> Enum.reject(&(&1.id == auth_user.id))
      |> Enum.each(&Repo.delete/1)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users")

      # Should only show the auth user
      assert html =~ auth_user.email
    end

    test "displays list of users", %{conn: conn, org: org} do
      # Create test users
      user1 = create_user(org, "user1@example.com", "User One", :active)
      user2 = create_user(org, "user2@example.com", "User Two", :pending_verification)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users")

      assert html =~ "user1@example.com"
      assert html =~ "User One"
      assert html =~ "user2@example.com"
      assert html =~ "User Two"
    end

    test "filters users by search query (email)", %{conn: conn, org: org} do
      create_user(org, "production@example.com", "Production User", :active)
      create_user(org, "development@example.com", "Development User", :active)

      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      # Search for "production"
      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{search: "production"})

      assert html =~ "production@example.com"
      refute html =~ "development@example.com"
    end

    test "filters users by search query (name)", %{conn: conn, org: org} do
      create_user(org, "john@example.com", "John Doe", :active)
      create_user(org, "jane@example.com", "Jane Smith", :active)

      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      # Search for "John"
      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{search: "John"})

      assert html =~ "John Doe"
      refute html =~ "Jane Smith"
    end

    test "filters users by active status", %{conn: conn, org: org} do
      active_user = create_user(org, "active@example.com", "Active User", :active)

      pending_user =
        create_user(org, "pending@example.com", "Pending User", :pending_verification)

      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      # Filter by active
      html =
        view
        |> element("form[phx-change='filter']")
        |> render_change(%{filter: "active"})

      assert html =~ "active@example.com"
      refute html =~ "pending@example.com"
    end

    test "filters users by pending_verification status", %{conn: conn, org: org} do
      active_user = create_user(org, "active@example.com", "Active User", :active)

      pending_user =
        create_user(org, "pending@example.com", "Pending User", :pending_verification)

      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      # Filter by pending_verification
      html =
        view
        |> element("form[phx-change='filter']")
        |> render_change(%{filter: "pending_verification"})

      refute html =~ "active@example.com"
      assert html =~ "pending@example.com"
    end

    test "filters users by suspended status", %{conn: conn, org: org} do
      active_user = create_user(org, "active@example.com", "Active User", :active)
      suspended_user = create_user(org, "suspended@example.com", "Suspended User", :suspended)

      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      # Filter by suspended
      html =
        view
        |> element("form[phx-change='filter']")
        |> render_change(%{filter: "suspended"})

      refute html =~ "active@example.com"
      assert html =~ "suspended@example.com"
    end

    test "deletes user successfully", %{conn: conn, org: org} do
      user = create_user(org, "delete@example.com", "User to Delete", :active)

      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      # Delete the user
      view
      |> element("button[phx-click='delete'][phx-value-id='#{user.id}']")
      |> render_click()

      # Verify user is removed from list
      refute render(view) =~ "delete@example.com"

      # Verify user is removed from database
      assert is_nil(Repo.get(UserSchema, user.id))
    end

    test "shows error when deleting non-existent user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      # Try to delete non-existent user
      render_hook(view, "delete", %{"id" => Ecto.UUID.generate()})

      # LiveView should handle the error gracefully
      assert render(view) =~ "Users"
    end

    test "displays user status badges", %{conn: conn, org: org} do
      create_user(org, "active@example.com", "Active User", :active)
      create_user(org, "pending@example.com", "Pending User", :pending_verification)
      create_user(org, "suspended@example.com", "Suspended User", :suspended)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users")

      assert html =~ "Active"
      assert html =~ "Pending"
      assert html =~ "Suspended"
    end

    test "displays verified badge for verified users", %{conn: conn, org: org} do
      verified_user = create_user(org, "verified@example.com", "Verified User", :active)
      # Mark as verified
      verified_user
      |> UserSchema.verify_email_changeset()
      |> Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/dashboard/users")

      assert html =~ "Verified"
    end

    test "displays organization name", %{conn: conn, org: org} do
      create_user(org, "user@example.com", "Test User", :active)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users")

      assert html =~ org.name
    end

    test "displays 'No organization' for users without org", %{conn: conn} do
      create_user(nil, "noorg@example.com", "No Org User", :active)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users")

      assert html =~ "No organization"
    end

    test "displays MFA status", %{conn: conn, org: org} do
      # User with MFA
      user_with_mfa = create_user(org, "mfa@example.com", "MFA User", :active)

      user_with_mfa
      |> UserSchema.update_changeset(%{
        mfa_methods: [
          %{"type" => "totp", "identifier" => "TOTP"}
        ]
      })
      |> Repo.update!()

      # User without MFA
      create_user(org, "nomfa@example.com", "No MFA User", :active)

      {:ok, _view, html} = live(conn, ~p"/dashboard/users")

      assert html =~ "1 methods"
      assert html =~ "None"
    end

    test "provides navigation to create new user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      assert has_element?(view, "a[href='/dashboard/users/new']", "New User")
    end

    test "provides navigation to view user details", %{conn: conn, org: org} do
      user = create_user(org, "view@example.com", "View User", :active)

      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      assert has_element?(
               view,
               "a[href='/dashboard/users/#{user.id}']",
               "View"
             )
    end

    test "provides navigation to edit user", %{conn: conn, org: org} do
      user = create_user(org, "edit@example.com", "Edit User", :active)

      {:ok, view, _html} = live(conn, ~p"/dashboard/users")

      assert has_element?(
               view,
               "a[href='/dashboard/users/#{user.id}/edit']",
               "Edit"
             )
    end
  end

  # Helper function to create test users
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
end
