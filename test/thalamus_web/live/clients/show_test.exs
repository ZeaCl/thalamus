defmodule ThalamusWeb.Clients.ShowTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    OAuth2ClientSchema,
    OrganizationSchema,
    TokenSchema
  }

  setup %{conn: conn} do
    # Clean up any existing organizations
    Repo.delete_all(OrganizationSchema)

    # Create test organization
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Test Organization",
        "plan_type" => "free"
      })
      |> Repo.insert!()

    # Create test client
    client = create_test_client(org, "Test Client", "confidential")

    # Log in user for protected routes
    conn = log_in_user(conn)

    {:ok, conn: conn, org: org, client: client}
  end

  describe "Show LiveView" do
    test "mounts successfully and displays client details", %{conn: conn, client: client} do
      {:ok, view, html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      assert html =~ "Client Details"
      assert html =~ client.name
      assert has_element?(view, "h1", client.name)
    end

    test "displays client information", %{conn: conn, client: client} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      assert html =~ client.name
      assert html =~ client.client_id_string
      assert html =~ "confidential"
    end

    test "displays token statistics", %{conn: conn, client: client} do
      # Create some tokens for the client
      create_token(client, "access_token")
      create_token(client, "access_token", revoked: true)

      {:ok, _view, html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      # Should show token stats
      assert html =~ "Total Tokens"
      assert html =~ "Active Tokens"
      assert html =~ "Revoked"
    end

    test "displays recent tokens", %{conn: conn, client: client} do
      # Create a token
      create_token(client, "access_token")

      {:ok, _view, html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      assert html =~ "Recent Tokens"
      # Check for token type badge or table content
      refute html =~ "No tokens issued yet"
    end

    test "displays empty state when no tokens exist", %{conn: conn, client: client} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      assert html =~ "No tokens issued yet"
    end

    test "shows client secret with toggle", %{conn: conn, client: client} do
      {:ok, view, html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      # Initially secret should be hidden
      assert html =~ "••••••••••••••••••••"
      assert has_element?(view, "button", "Show")

      # Toggle to show
      html =
        view
        |> element("button[phx-click='toggle_secret']")
        |> render_click()

      assert has_element?(view, "button", "Hide")
    end

    test "allows rotating client secret", %{conn: conn, client: client} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      # Click rotate secret button
      html =
        view
        |> element("button[phx-click='rotate_secret']")
        |> render_click()

      # Should display new secret warning
      assert html =~ "New Client Secret Generated!"
      assert html =~ "Please save this secret securely"

      # Verify secret was actually rotated in database
      updated_client = Repo.get_by(OAuth2ClientSchema, client_id_string: client.client_id_string)
      refute updated_client.client_secret == client.client_secret
    end

    test "displays OAuth2 configuration", %{conn: conn, client: client} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      assert html =~ "OAuth2 Configuration"
      assert html =~ "Grant Types"
      assert html =~ "Allowed Scopes"
    end

    test "provides navigation back to clients list", %{conn: conn, client: client} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      assert has_element?(view, "a[href='/dashboard/clients']", "Back to Clients")
    end

    test "provides navigation to edit client", %{conn: conn, client: client} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/clients/#{client.client_id_string}")

      assert has_element?(
               view,
               "a[href='/dashboard/clients/#{client.client_id_string}/edit']",
               "Edit"
             )
    end

    test "redirects when client not found", %{conn: conn} do
      result = live(conn, ~p"/dashboard/clients/nonexistent-id")

      assert {:error, {:live_redirect, %{to: "/dashboard/clients"}}} = result
    end
  end

  # Helper functions
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

  defp create_token(client, type, attrs \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, 3600, :second)

    attrs_map = Enum.into(attrs, %{})
    revoked = Map.get(attrs_map, :revoked, false)

    %TokenSchema{
      token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      type: String.to_atom(type),
      # Use the UUID id, not client_id_string
      client_id: client.id,
      scopes: ["openid", "profile"],
      expires_at: expires_at,
      revoked: revoked,
      inserted_at: now
    }
    |> Repo.insert!()
  end
end
