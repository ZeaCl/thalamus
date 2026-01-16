defmodule ThalamusWeb.Organizations.IndexTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{OrganizationSchema, UserSchema}

  setup %{conn: conn} do
    # Create an auth user
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Auth Org",
        "plan_type" => "free"
      })
      |> Repo.insert!()

    auth_user = create_user(org, "admin@example.com")

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, auth_user.id)

    # Log in user for protected routes
    conn = log_in_user(conn)

    {:ok, conn: conn, conn: conn, org: org}
  end

  describe "Index LiveView" do
    test "mounts successfully and displays page title", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/organizations")

      assert html =~ "Organizations"
      assert has_element?(view, "h1", "Organizations")
    end

    test "displays list of organizations", %{conn: conn} do
      create_organization("Test Org 1", "free")
      create_organization("Test Org 2", "starter")

      {:ok, _view, html} = live(conn, ~p"/dashboard/organizations")

      assert html =~ "Test Org 1"
      assert html =~ "Test Org 2"
    end

    test "filters by search query", %{conn: conn} do
      create_organization("Production Corp", "professional")
      create_organization("Development Ltd", "free")

      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations")

      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{search: "Production"})

      assert html =~ "Production Corp"
      refute html =~ "Development Ltd"
    end

    test "filters by status", %{conn: conn} do
      org1 = create_organization("Active Org", "free")
      org2 = create_organization("Trial Org", "starter")

      # Update status
      OrganizationSchema.reactivate_changeset(org1) |> Repo.update!()

      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations")

      html =
        view
        |> element("form[phx-change='filter_status']")
        |> render_change(%{status: "active"})

      assert html =~ "Active Org"
      refute html =~ "Trial Org"
    end

    test "filters by plan type", %{conn: conn} do
      create_organization("Free Org", "free")
      create_organization("Enterprise Org", "enterprise")

      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations")

      html =
        view
        |> element("form[phx-change='filter_plan']")
        |> render_change(%{plan: "enterprise"})

      refute html =~ "Free Org"
      assert html =~ "Enterprise Org"
    end

    test "deletes organization", %{conn: conn} do
      org = create_organization("Delete Me", "free")

      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations")

      view
      |> element("button[phx-click='delete'][phx-value-id='#{org.id}']")
      |> render_click()

      refute render(view) =~ "Delete Me"
      assert is_nil(Repo.get(OrganizationSchema, org.id))
    end

    test "shows plan badges", %{conn: conn} do
      create_organization("Test Org", "professional")

      {:ok, _view, html} = live(conn, ~p"/dashboard/organizations")

      assert html =~ "Professional"
    end

    test "provides navigation to create new org", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations")

      assert has_element?(view, "a[href='/dashboard/organizations/new']", "New Organization")
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
