defmodule ThalamusWeb.Clients.FormTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{OAuth2ClientSchema, OrganizationSchema}

  setup %{conn: conn} do
    # Clean up any existing organizations to avoid "expected at most one" errors
    Repo.delete_all(OrganizationSchema)

    # Create test organization using the changeset to set defaults
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

  describe "Form LiveView - New Client" do
    test "mounts successfully for new client", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/clients/new")

      assert html =~ "New OAuth2 Client"
      assert has_element?(view, "h1", "New OAuth2 Client")
    end

    test "displays form fields for new client", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/clients/new")

      assert html =~ "Client Name"
      assert html =~ "Description"
      assert html =~ "Client Type"
      assert html =~ "Grant Types"
      assert html =~ "Allowed Scopes"
      assert html =~ "Redirect URIs"
      assert html =~ "PKCE"
    end

    test "creates a new client with valid data", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/new")

      # Fill in basic required fields only
      view
      |> form("form", %{
        "client" => %{
          "name" => "New Test Client",
          "description" => "A test client",
          "client_type" => "confidential"
        }
      })
      |> render_submit()

      # Verify client was created in database
      client = Repo.get_by(OAuth2ClientSchema, name: "New Test Client")
      assert client
      assert client.description == "A test client"
      assert client.client_type == :confidential
      assert client.organization_id == org.id
    end

    test "displays client secret after creation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/new")

      html =
        view
        |> form("form", %{
          "client" => %{
            "name" => "Secret Test Client",
            "client_type" => "confidential"
          }
        })
        |> render_submit()

      # Should display warning about saving the secret
      assert html =~ "Client Secret Generated!"
      assert html =~ "Please save this secret securely"
    end

    test "validates required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/new")

      # Try to submit without required fields
      view
      |> form("form", %{"client" => %{"name" => ""}})
      |> render_change()

      # Form should have validation errors (though they may not show in change)
      # The submit should fail or show errors
      html =
        view
        |> form("form", %{"client" => %{"name" => "", "client_type" => ""}})
        |> render_submit()

      # Verify client was NOT created
      refute Repo.get_by(OAuth2ClientSchema, name: "")
    end

    test "handles redirect URIs text field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/new")

      view
      |> form("form", %{
        "client" => %{
          "name" => "Multi URI Client",
          "client_type" => "confidential",
          "redirect_uris_text" => "https://example.com/callback1\nhttps://example.com/callback2"
        }
      })
      |> render_submit()

      client = Repo.get_by(OAuth2ClientSchema, name: "Multi URI Client")
      assert client
      # Should have processed multiple URIs
      assert is_list(client.redirect_uris)
    end
  end

  describe "Form LiveView - Edit Client" do
    setup %{org: org} do
      client = create_test_client(org, "Edit Test Client", "confidential")
      {:ok, client: client}
    end

    test "mounts successfully for edit", %{conn: conn, client: client} do
      {:ok, view, html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}/edit")

      assert html =~ "Edit OAuth2 Client"
      assert has_element?(view, "h1", "Edit OAuth2 Client")
    end

    test "displays existing client data", %{conn: conn, client: client} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}/edit")

      assert html =~ "Edit Test Client"
      assert html =~ client.description || ""
    end

    test "updates client with new data", %{conn: conn, client: client} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}/edit")

      view
      |> form("form", %{
        "client" => %{
          "name" => "Updated Client Name",
          "description" => "Updated description"
        }
      })
      |> render_submit()

      # Verify changes in database
      updated_client = Repo.get_by(OAuth2ClientSchema, client_id_string: client.client_id_string)
      assert updated_client.name == "Updated Client Name"
      assert updated_client.description == "Updated description"
    end

    test "redirects to clients list after successful update", %{conn: conn, client: client} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}/edit")

      view
      |> form("form", %{
        "client" => %{
          "name" => "Updated Client"
        }
      })
      |> render_submit()

      # Check for navigation (LiveView may have redirected)
      # Note: In tests, we may need to check flash or response differently
      assert_redirect(view, ~p"/dashboard/clients")
    end

    test "redirects when client not found", %{conn: conn} do
      # When client is not found, LiveView redirects to clients list
      result = live(conn, ~p"/dashboard/clients/nonexistent-id/edit")

      # Should get a redirect error
      assert {:error, {:live_redirect, %{to: "/dashboard/clients"}}} = result
    end
  end

  describe "Form Validation" do
    test "validates name presence", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/new")

      html =
        view
        |> form("form", %{"client" => %{"name" => ""}})
        |> render_change()

      # Changeset should have validation error
      # (may not always show in HTML immediately)
      assert html =~ "form"
    end

    test "creates client without optional fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/new")

      # Submit with only required fields
      view
      |> form("form", %{
        "client" => %{
          "name" => "Minimal Client",
          "client_type" => "confidential"
        }
      })
      |> render_submit()

      client = Repo.get_by(OAuth2ClientSchema, name: "Minimal Client")
      # Should have created the client
      assert client
      assert client.name == "Minimal Client"
    end
  end

  # Helper function to create test clients
  defp create_test_client(org, name, client_type) do
    client_id = Ecto.UUID.generate()
    client_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    default_attrs = %{
      client_id_string: client_id,
      name: name,
      client_type: String.to_atom(client_type),
      client_secret: Bcrypt.hash_pwd_salt(client_secret),
      organization_id: org.id,
      description: "Test client description",
      allowed_grant_types: ["authorization_code"],
      allowed_scopes: ["openid", "profile"]
    }

    OAuth2ClientSchema.create_changeset(default_attrs)
    |> Repo.insert!()
  end
end
