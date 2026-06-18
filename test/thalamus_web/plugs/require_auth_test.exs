defmodule ThalamusWeb.Plugs.RequireAuthTest do
  use ThalamusWeb.ConnCase, async: false

  alias ThalamusWeb.Plugs.RequireAuth

  describe "RequireAuth plug" do
    test "redirects to login when user is not authenticated", %{conn: conn} do
      conn =
        conn
        |> get("/dashboard")

      # Should redirect to login with return_to parameter
      # Note: redirected_to/1 automatically decodes URLs
      assert redirected_to(conn) == "/login?return_to=/dashboard"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must be logged in to access this page"
    end

    test "redirects to login with full path including query string", %{conn: conn} do
      conn =
        conn
        |> get("/dashboard/clients?filter=active")

      # Should preserve query string in return_to
      # Note: redirected_to/1 automatically decodes URLs
      assert redirected_to(conn) == "/login?return_to=/dashboard/clients?filter=active"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must be logged in to access this page"
    end

    test "allows request when user is authenticated", %{conn: conn} do
      # Simulate authenticated session
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, "user_123")
        |> RequireAuth.call([])

      # Should not redirect
      refute conn.halted
      assert conn.status == nil
    end

    test "halts connection after redirect", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> bypass_through(ThalamusWeb.Router, [:dashboard])
        |> get("/dashboard")

      # Should halt the connection (prevent further processing)
      assert conn.halted
    end
  end

  describe "Integration with dashboard routes" do
    test "dashboard index requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/dashboard")

      assert redirected_to(conn) == "/login?return_to=/dashboard"
    end

    test "clients index requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/dashboard/clients")

      assert redirected_to(conn) == "/login?return_to=/dashboard/clients"
    end

    test "clients new form requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/dashboard/clients/new")

      assert redirected_to(conn) == "/login?return_to=/dashboard/clients/new"
    end

    test "clients show page requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/dashboard/clients/test-client-id")

      assert redirected_to(conn) == "/login?return_to=/dashboard/clients/test-client-id"
    end

    test "clients edit form requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/dashboard/clients/test-client-id/edit")

      assert redirected_to(conn) == "/login?return_to=/dashboard/clients/test-client-id/edit"
    end
  end

  describe "Authenticated access" do
    setup %{conn: conn} do
      # Create a real user
      {:ok, user} =
        Thalamus.Domain.Entities.User.register("test_plug_user@example.com", "Password123!")

      {:ok, user} = Thalamus.Domain.Entities.User.verify_email(user)
      {:ok, user} = Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository.save(user)

      # Create authenticated connection
      authenticated_conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, user.id)

      {:ok, authenticated_conn: authenticated_conn}
    end

    test "allows access to dashboard when authenticated", %{authenticated_conn: conn} do
      conn = get(conn, ~p"/dashboard")

      # Should not redirect
      assert html_response(conn, 200) =~ "Dashboard"
    end

    test "allows access to clients index when authenticated", %{authenticated_conn: conn} do
      conn = get(conn, ~p"/dashboard/clients")

      # Should not redirect
      assert html_response(conn, 200) =~ "Multi-Agent Clients"
    end

    test "allows access to clients new form when authenticated", %{authenticated_conn: conn} do
      conn = get(conn, ~p"/dashboard/clients/new")

      # Should not redirect
      assert html_response(conn, 200) =~ "New OAuth2 Client"
    end
  end

  describe "Login flow with return_to" do
    test "preserves return_to in redirect URL", %{conn: conn} do
      # Try to access dashboard without auth
      conn = get(conn, ~p"/dashboard/clients")

      # Should redirect to login with return_to parameter
      assert redirected_to(conn) == "/login?return_to=/dashboard/clients"

      # Verify the flash message is set
      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must be logged in to access this page"
    end
  end
end
