defmodule ThalamusWeb.Clients.IndexTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    OAuth2ClientSchema,
    OrganizationSchema,
    UserSchema
  }

  setup %{conn: conn} do
    # Create test organization using the changeset to set defaults
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Test Org #{System.unique_integer()}",
        "plan_type" => "free"
      })
      |> Repo.insert!()

    # Create auth user in the test organization
    auth_user = create_user(org, "admin@example.com")

    # Log in user for protected routes
    conn = log_in_user(conn, auth_user.id)

    {:ok, conn: conn, org: org, auth_user: auth_user}
  end

  describe "Index LiveView" do
    test "mounts successfully and displays page title", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/clients")

      assert html =~ "Multi-Agent Clients"
      assert has_element?(view, "h1", "Multi-Agent Clients")
    end

    test "displays empty state when no clients exist", %{conn: conn} do
      # Clean up any existing clients from seed data
      Repo.delete_all(OAuth2ClientSchema)

      {:ok, _view, html} = live(conn, ~p"/dashboard/clients")

      assert html =~ "No clients found"
      assert html =~ "Get started by creating a new OAuth2 client"
    end

    test "displays list of clients", %{conn: conn, org: org} do
      # Create test clients
      client1 = create_client(org, "Test Client 1", "confidential")
      client2 = create_client(org, "Test Client 2", "m2m")

      {:ok, _view, html} = live(conn, ~p"/dashboard/clients")

      assert html =~ "Test Client 1"
      assert html =~ "Test Client 2"
      assert html =~ client1.client_id_string
      assert html =~ client2.client_id_string
    end

    test "filters clients by search query", %{conn: conn, org: org} do
      create_client(org, "Production Client", "confidential")
      create_client(org, "Development Client", "confidential")

      {:ok, view, _html} = live(conn, ~p"/dashboard/clients")

      # Search for "Production"
      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{search: "Production"})

      assert html =~ "Production Client"
      refute html =~ "Development Client"
    end

    test "filters clients by active status", %{conn: conn, org: org} do
      active_client = create_client(org, "Active Client", "confidential", is_active: true)
      inactive_client = create_client(org, "Inactive Client", "confidential", is_active: false)

      # Verify they were created correctly
      assert Repo.get_by(OAuth2ClientSchema, client_id_string: active_client.client_id_string).is_active ==
               true

      assert Repo.get_by(OAuth2ClientSchema, client_id_string: inactive_client.client_id_string).is_active ==
               false

      {:ok, view, _html} = live(conn, ~p"/dashboard/clients")

      # Filter by active
      html =
        view
        |> element("form[phx-change='filter']")
        |> render_change(%{filter: "active"})

      assert html =~ "Active Client"
      refute html =~ "Inactive Client"

      # Filter by inactive
      html =
        view
        |> element("form[phx-change='filter']")
        |> render_change(%{filter: "inactive"})

      refute html =~ "Active Client"
      assert html =~ "Inactive Client"
    end

    test "deletes client successfully", %{conn: conn, org: org} do
      client = create_client(org, "Client to Delete", "confidential")

      {:ok, view, _html} = live(conn, ~p"/dashboard/clients")

      # Delete the client
      view
      |> element("button[phx-click='delete'][phx-value-id='#{client.client_id_string}']")
      |> render_click()

      # Verify client is removed from list
      refute render(view) =~ "Client to Delete"

      # Verify client is removed from database
      assert is_nil(Repo.get_by(OAuth2ClientSchema, client_id_string: client.client_id_string))
    end

    test "shows error when deleting non-existent client", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients")

      # Try to delete non-existent client by sending the event directly
      render_hook(view, "delete", %{"id" => "nonexistent-id"})

      # LiveView should handle the error gracefully (client not found)
      # We just verify it doesn't crash
      assert render(view) =~ "Multi-Agent Clients"
    end

    test "displays client badges and metadata", %{conn: conn, org: org} do
      create_client(org, "Test Client", "m2m",
        allowed_grant_types: ["client_credentials"],
        is_active: true
      )

      {:ok, _view, html} = live(conn, ~p"/dashboard/clients")

      assert html =~ "m2m"
      assert html =~ "Active"
      assert html =~ "client_credentials"
    end

    test "provides navigation to create new client", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients")

      assert has_element?(view, "a[href='/dashboard/clients/new']", "New Client")
    end

    test "provides navigation to view client details", %{conn: conn, org: org} do
      client = create_client(org, "Test Client", "confidential")

      {:ok, view, _html} = live(conn, ~p"/dashboard/clients")

      assert has_element?(
               view,
               "a[href='/dashboard/clients/#{client.client_id_string}']",
               "View"
             )
    end

    test "provides navigation to edit client", %{conn: conn, org: org} do
      client = create_client(org, "Test Client", "confidential")

      {:ok, view, _html} = live(conn, ~p"/dashboard/clients")

      assert has_element?(
               view,
               "a[href='/dashboard/clients/#{client.client_id_string}/edit']",
               "Edit"
             )
    end
  end

  # Helper functions
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

  defp create_client(org, name, client_type, attrs \\ []) do
    client_id = Ecto.UUID.generate()
    client_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    attrs_map = Enum.into(attrs, %{})
    is_active = Map.get(attrs_map, :is_active, true)

    default_attrs = %{
      client_id_string: client_id,
      name: name,
      client_type: String.to_atom(client_type),
      client_secret: Bcrypt.hash_pwd_salt(client_secret),
      organization_id: org.id,
      allowed_grant_types: Map.get(attrs_map, :allowed_grant_types, ["authorization_code"]),
      allowed_scopes: Map.get(attrs_map, :allowed_scopes, ["openid", "profile"])
    }

    client =
      OAuth2ClientSchema.create_changeset(default_attrs)
      |> Repo.insert!()

    # Update is_active if needed (create_changeset doesn't accept it)
    if is_active != true do
      client
      |> OAuth2ClientSchema.update_changeset(%{is_active: is_active})
      |> Repo.update!()
    else
      client
    end
  end
end
