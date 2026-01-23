defmodule ThalamusWeb.Organizations.ShowTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{OrganizationSchema, UserSchema}

  setup %{conn: conn} do
    # Create an auth user with unique org to prevent deadlocks
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Auth Org #{System.unique_integer()}",
        "plan_type" => "free"
      })
      |> Repo.insert!()

    auth_user = create_user(org, "admin@example.com")

    # Create test organization with unique name to prevent deadlocks
    test_org = create_organization("Test Org #{System.unique_integer()}", "standard")

    # Log in user for protected routes (loads user into session and assigns)
    conn = log_in_user(conn, auth_user.id)

    {:ok, conn: conn, org: test_org, auth_user: auth_user}
  end

  describe "Show LiveView" do
    test "mounts successfully and displays details", %{conn: conn, org: org} do
      {:ok, view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      assert html =~ "Organization Details"
      assert html =~ org.name
      assert has_element?(view, "h1", org.name)
    end

    test "displays organization information", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      assert html =~ org.name
      assert html =~ "Professional"
      assert html =~ "Trial"
    end

    test "displays plan limits", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      assert html =~ "Max Users"
      assert html =~ "Max API Calls"
      assert html =~ "MFA Required"
    end

    test "displays statistics", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      assert html =~ "Users"
      assert html =~ "OAuth2 Clients"
      assert html =~ "API Calls"
    end

    test "allows verifying organization", %{conn: conn, org: org} do
      {:ok, view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      assert html =~ "Verify Organization"

      html =
        view
        |> element("button[phx-click='verify']")
        |> render_click()

      assert html =~ "Yes"

      updated = Repo.get(OrganizationSchema, org.id)
      assert updated.verified == true
      assert updated.status == :active
    end

    test "allows suspending organization", %{conn: conn} do
      org = create_organization("Suspend Org", "free")
      org = OrganizationSchema.reactivate_changeset(org) |> Repo.update!()

      {:ok, view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      assert html =~ "Suspend Organization"

      html =
        view
        |> element("button[phx-click='suspend']")
        |> render_click()

      assert html =~ "Suspended"

      updated = Repo.get(OrganizationSchema, org.id)
      assert updated.status == :suspended
    end

    test "allows reactivating suspended organization", %{conn: conn} do
      org = create_organization("Reactivate Org", "free")
      org = OrganizationSchema.suspend_changeset(org) |> Repo.update!()

      {:ok, view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      assert html =~ "Reactivate Organization"

      html =
        view
        |> element("button[phx-click='reactivate']")
        |> render_click()

      assert html =~ "Active"

      updated = Repo.get(OrganizationSchema, org.id)
      assert updated.status == :active
    end

    test "allows changing plan", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      html =
        view
        |> element("select[phx-change='change_plan']")
        |> render_change(%{plan: "enterprise"})

      assert html =~ "Enterprise"

      updated = Repo.get(OrganizationSchema, org.id)
      assert updated.plan_type == :enterprise
    end

    test "displays recent users", %{conn: conn, org: org} do
      create_user(org, "user1@example.com")
      create_user(org, "user2@example.com")

      {:ok, _view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      assert html =~ "Recent Users"
      assert html =~ "user1@example.com"
      assert html =~ "user2@example.com"
    end

    test "provides navigation to edit", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations/#{org.id}")

      assert has_element?(view, "a[href='/dashboard/organizations/#{org.id}/edit']", "Edit")
    end

    test "redirects when org not found", %{conn: conn} do
      result = live(conn, ~p"/dashboard/organizations/#{Ecto.UUID.generate()}")

      assert {:error, {:live_redirect, %{to: "/dashboard/organizations"}}} = result
    end
  end

  # Helper functions
  defp create_organization(name, plan_type) do
    OrganizationSchema.create_changeset(%{
      "name" => name,
      "plan_type" => plan_type
    })
    |> Repo.insert!()
  end

  defp create_user(org, email) do
    password_hash = Bcrypt.hash_pwd_salt("password123")

    UserSchema.create_changeset(%{
      email: email,
      password_hash: password_hash,
      status: :active,
      organization_id: org.id
    })
    |> Repo.insert!()
  end
end
