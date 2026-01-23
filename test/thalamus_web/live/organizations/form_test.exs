defmodule ThalamusWeb.Organizations.FormTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{OrganizationSchema, UserSchema}

  setup %{conn: conn} do
    # Create an auth user
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Auth Org #{System.unique_integer()}",
        "plan_type" => "free"
      })
      |> Repo.insert!()

    auth_user = create_user(org, "admin@example.com")

    # Log in user for protected routes (loads user into session and assigns)
    conn = log_in_user(conn, auth_user.id)

    {:ok, conn: conn, org: org, auth_user: auth_user}
  end

  describe "Form LiveView - New Organization" do
    test "mounts successfully for new org", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/organizations/new")

      assert html =~ "New Organization"
      assert has_element?(view, "h1", "New Organization")
    end

    test "creates organization with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations/new")

      view
      |> form("form", %{
        "organization" => %{
          "name" => "New Test Org",
          "plan_type" => "standard"
        }
      })
      |> render_submit()

      org = Repo.get_by(OrganizationSchema, name: "New Test Org")
      assert org
      assert org.plan_type == :standard
      assert org.status == :trial
      assert org.verified == false
    end

    test "validates required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations/new")

      html =
        view
        |> form("form", %{"organization" => %{"name" => ""}})
        |> render_submit()

      refute Repo.get_by(OrganizationSchema, name: "")
    end

    test "prevents duplicate names", %{conn: conn} do
      create_organization("Duplicate Org", "free")

      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations/new")

      view
      |> form("form", %{
        "organization" => %{
          "name" => "Duplicate Org #{System.unique_integer()}",
          "plan_type" => "free"
        }
      })
      |> render_submit()

      orgs = Repo.all(OrganizationSchema) |> Enum.filter(&(&1.name == "Duplicate Org"))
      assert length(orgs) == 1
    end
  end

  describe "Form LiveView - Edit Organization" do
    setup %{org: org} do
      edit_org = create_organization("Edit Test Org", "basic")
      {:ok, edit_org: edit_org}
    end

    test "mounts successfully for edit", %{conn: conn, edit_org: org} do
      {:ok, view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}/edit")

      assert html =~ "Edit Organization"
      assert has_element?(view, "h1", "Edit Organization")
    end

    test "displays existing data", %{conn: conn, edit_org: org} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/organizations/#{org.id}/edit")

      assert html =~ "Edit Test Org"
    end

    test "updates organization", %{conn: conn, edit_org: org} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/organizations/#{org.id}/edit")

      view
      |> form("form", %{
        "organization" => %{
          "name" => "Updated Org Name"
        }
      })
      |> render_submit()

      updated = Repo.get(OrganizationSchema, org.id)
      assert updated.name == "Updated Org Name"
    end

    test "redirects when org not found", %{conn: conn} do
      result = live(conn, ~p"/dashboard/organizations/#{Ecto.UUID.generate()}/edit")

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
