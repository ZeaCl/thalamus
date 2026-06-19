defmodule ThalamusWeb.Dashboard.PlaceholderLiveTest do
  use ThalamusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{OrganizationSchema, UserSchema}

  setup %{conn: conn} do
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Test Org",
        "plan_type" => "free"
      })
      |> Repo.insert!()

    auth_user = create_user(org, "admin@example.com")
    conn = log_in_user(conn, auth_user.id)

    {:ok, conn: conn, org: org, auth_user: auth_user}
  end

  describe "PlaceholderLive with organization" do
    test "mounts successfully for workflows", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/workflows")
      assert html =~ "Stateful Workflows"
    end

    test "mounts successfully for identity", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/identity")
      assert html =~ "Identity" and html =~ "Access"
    end

    test "mounts successfully for billing", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/billing")
      assert html =~ "Current Plan"
    end
  end

  describe "PlaceholderLive without organization" do
    setup %{conn: conn} do
      # Create a user with NO organization
      auth_user = create_user(nil, "no-org@example.com")
      conn = log_in_user(conn, auth_user.id)

      {:ok, conn: conn, auth_user: auth_user}
    end

    test "mounts successfully for workflows", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/workflows")
      assert html =~ "Stateful Workflows"
    end

    test "mounts successfully for identity", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/identity")
      assert html =~ "Identity" and html =~ "Access"
    end

    test "mounts successfully for billing", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/billing")
      assert html =~ "Current Plan"
    end
  end

  defp create_user(org, email) do
    password_hash = Bcrypt.hash_pwd_salt("password123")
    org_id = if org, do: org.id, else: nil

    UserSchema.create_changeset(%{
      email: email,
      password_hash: password_hash,
      status: :active,
      organization_id: org_id
    })
    |> Repo.insert!()
  end
end
