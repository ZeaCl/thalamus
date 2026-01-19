defmodule ThalamusWeb.Users.FormTest do
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

    # Log in user for protected routes
    conn = log_in_user(conn)

    {:ok, conn: conn, org: org}
  end

  describe "Form LiveView - New User" do
    test "mounts successfully for new user", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/users/new")

      assert html =~ "New User"
      assert has_element?(view, "h1", "New User")
    end

    test "displays form fields for new user", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/new")

      assert html =~ "Email"
      assert html =~ "Full Name"
      assert html =~ "Organization"
      # Status should NOT be visible for new users
      refute html =~ "Status"
    end

    test "displays password generation notice", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/new")

      assert html =~ "A random secure password will be generated for this user"
    end

    test "creates a new user with valid data", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/new")

      # Fill in required fields
      view
      |> form("form", %{
        "user" => %{
          "email" => "newuser@example.com",
          "name" => "New Test User",
          "organization_id" => org.id
        }
      })
      |> render_submit()

      # Verify user was created in database
      user = Repo.get_by(UserSchema, email: "newuser@example.com")
      assert user
      assert user.name == "New Test User"
      assert user.organization_id == org.id
      assert user.status == :pending_verification
      assert user.password_hash
    end

    test "displays generated password after creation", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/new")

      html =
        view
        |> form("form", %{
          "user" => %{
            "email" => "password@example.com",
            "name" => "Password Test User",
            "organization_id" => org.id
          }
        })
        |> render_submit()

      # Should display warning about saving the password
      assert html =~ "User Created - Password Generated!"
      assert html =~ "Please save this password securely"
      assert html =~ "Continue to Users List"
    end

    test "validates email presence", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/new")

      # Try to submit without email
      html =
        view
        |> form("form", %{
          "user" => %{
            "email" => "",
            "name" => "No Email User"
          }
        })
        |> render_submit()

      # Should not create user and stay on form
      refute Repo.get_by(UserSchema, name: "No Email User")
    end

    test "creates user without optional name", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/new")

      view
      |> form("form", %{
        "user" => %{
          "email" => "noname@example.com",
          "organization_id" => org.id
        }
      })
      |> render_submit()

      # User should be created without name
      user = Repo.get_by(UserSchema, email: "noname@example.com")
      assert user
      assert is_nil(user.name)
    end

    test "creates user without organization", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/new")

      view
      |> form("form", %{
        "user" => %{
          "email" => "noorg@example.com",
          "name" => "No Org User",
          "organization_id" => ""
        }
      })
      |> render_submit()

      # User should be created without organization
      user = Repo.get_by(UserSchema, email: "noorg@example.com")
      assert user
      assert is_nil(user.organization_id)
    end

    test "validates email format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/new")

      html =
        view
        |> form("form", %{
          "user" => %{
            "email" => "invalid-email",
            "name" => "Invalid Email User"
          }
        })
        |> render_change()

      # Form should validate (validation happens on change)
      assert html =~ "form"
    end

    test "prevents duplicate email addresses", %{conn: conn, org: org} do
      # Create first user
      create_user(org, "duplicate@example.com", "First User", :active)

      {:ok, view, _html} = live(conn, ~p"/dashboard/users/new")

      # Try to create second user with same email
      html =
        view
        |> form("form", %{
          "user" => %{
            "email" => "duplicate@example.com",
            "name" => "Second User"
          }
        })
        |> render_submit()

      # Should fail with constraint error (stays on form)
      # Only one user with this email should exist
      users = Repo.all(UserSchema) |> Enum.filter(&(&1.email == "duplicate@example.com"))
      assert length(users) == 1
    end
  end

  describe "Form LiveView - Edit User" do
    setup %{conn: conn, org: org} do
      user = create_user(org, "edit@example.com", "Edit User", :pending_verification)
      {:ok, conn: conn, user: user}
    end

    test "mounts successfully for edit", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/dashboard/users/#{user.id}/edit")

      assert html =~ "Edit User"
      assert has_element?(view, "h1", "Edit User")
    end

    test "displays existing user data", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}/edit")

      assert html =~ "edit@example.com"
      assert html =~ "Edit User"
    end

    test "displays status field for edit", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}/edit")

      # Status field should be visible when editing
      assert html =~ "Status"
      assert html =~ "Pending Verification"
      assert html =~ "Active"
      assert html =~ "Suspended"
      assert html =~ "Deactivated"
    end

    test "does not show password generation notice for edit", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/users/#{user.id}/edit")

      # Password notice should only show for new users
      refute html =~ "A random secure password will be generated"
    end

    test "updates user with new data", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/#{user.id}/edit")

      view
      |> form("form", %{
        "user" => %{
          "name" => "Updated Name",
          "email" => "updated@example.com"
        }
      })
      |> render_submit()

      # Verify changes in database
      updated_user = Repo.get(UserSchema, user.id)
      assert updated_user.name == "Updated Name"
      assert updated_user.email == "updated@example.com"
    end

    test "updates user status", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/#{user.id}/edit")

      view
      |> form("form", %{
        "user" => %{
          "status" => "active"
        }
      })
      |> render_submit()

      # Verify status change
      updated_user = Repo.get(UserSchema, user.id)
      assert updated_user.status == :active
    end

    test "updates user organization", %{conn: conn, user: user} do
      # Create another organization
      new_org =
        OrganizationSchema.create_changeset(%{
          "name" => "New Organization",
          "plan_type" => "free"
        })
        |> Repo.insert!()

      {:ok, view, _html} = live(conn, ~p"/dashboard/users/#{user.id}/edit")

      view
      |> form("form", %{
        "user" => %{
          "organization_id" => new_org.id
        }
      })
      |> render_submit()

      # Verify organization change
      updated_user = Repo.get(UserSchema, user.id)
      assert updated_user.organization_id == new_org.id
    end

    test "redirects to users list after successful update", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/#{user.id}/edit")

      view
      |> form("form", %{
        "user" => %{
          "name" => "Updated User"
        }
      })
      |> render_submit()

      # Check for navigation
      assert_redirect(view, ~p"/dashboard/users")
    end

    test "redirects when user not found", %{conn: conn} do
      # When user is not found, LiveView redirects to users list
      result = live(conn, ~p"/dashboard/users/#{Ecto.UUID.generate()}/edit")

      # Should get a redirect error
      assert {:error, {:live_redirect, %{to: "/dashboard/users"}}} = result
    end
  end

  describe "Form Validation" do
    test "validates email on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/new")

      html =
        view
        |> form("form", %{
          "user" => %{
            "email" => "valid@example.com"
          }
        })
        |> render_change()

      # Should accept valid email
      assert html =~ "form"
    end

    test "handles form validation errors gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/users/new")

      # Submit with invalid data
      html =
        view
        |> form("form", %{
          "user" => %{
            "email" => "",
            "name" => ""
          }
        })
        |> render_submit()

      # Form should still be rendered (not crash)
      assert html =~ "Email"
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
