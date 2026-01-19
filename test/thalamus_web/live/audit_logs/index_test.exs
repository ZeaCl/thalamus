defmodule ThalamusWeb.AuditLogs.IndexTest do
  use ThalamusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Thalamus.Repo

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    AuditLogSchema,
    UserSchema,
    OrganizationSchema,
    OAuth2ClientSchema
  }

  setup %{conn: conn} do
    # Create an organization
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Test Org #{System.unique_integer()}",
        "plan_type" => "professional"
      })
      |> Repo.insert!()

    # Create an auth user
    auth_user = create_user(org, "admin@example.com", "Admin User")

    # Create test user
    test_user = create_user(org, "user@example.com", "Test User")

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, auth_user.id)

    # Log in user for protected routes
    conn = log_in_user(conn)

    {:ok, conn: conn, conn: conn, org: org, user: test_user}
  end

  describe "Index LiveView" do
    test "mounts successfully and displays page title", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/audit-logs")

      assert html =~ "Audit Logs"
      assert has_element?(view, "h1", "Audit Logs")
    end

    test "displays list of audit logs", %{conn: conn, user: user, org: org} do
      create_audit_log("authentication_success", user, org)
      create_audit_log("token_generated", user, org)

      {:ok, _view, html} = live(conn, ~p"/dashboard/audit-logs")

      assert html =~ "Auth Success"
      assert html =~ "Token Generated"
    end

    test "filters by search query (user email)", %{conn: conn, org: org} do
      user1 = create_user(org, "alice@example.com", "Alice")
      user2 = create_user(org, "bob@example.com", "Bob")

      create_audit_log("authentication_success", user1, org)
      create_audit_log("authentication_success", user2, org)

      {:ok, view, _html} = live(conn, ~p"/dashboard/audit-logs")

      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{search: "alice"})

      assert html =~ "alice@example.com"
      refute html =~ "bob@example.com"
    end

    test "filters by search query (IP address)", %{conn: conn, user: user, org: org} do
      create_audit_log("authentication_success", user, org, %{ip_address: "192.168.1.1"})
      create_audit_log("authentication_success", user, org, %{ip_address: "10.0.0.1"})

      {:ok, view, _html} = live(conn, ~p"/dashboard/audit-logs")

      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{search: "192.168"})

      assert html =~ "192.168.1.1"
      refute html =~ "10.0.0.1"
    end

    test "filters by event type", %{conn: conn, user: user, org: org} do
      create_audit_log("authentication_success", user, org)
      create_audit_log("token_generated", user, org)
      create_audit_log("password_changed", user, org)

      {:ok, view, _html} = live(conn, ~p"/dashboard/audit-logs")

      html =
        view
        |> element("form[phx-change='filter_event_type']")
        |> render_change(%{event_type: "authentication_success"})

      # Should show only authentication_success events
      auth_success_count = html |> String.split("Auth Success") |> length() |> Kernel.-(1)
      assert auth_success_count == 1
    end

    test "filters by date range - last hour", %{conn: conn, user: user, org: org} do
      # Create log from 2 hours ago
      old_log_attrs = %{
        event_type: "authentication_success",
        user_id: user.id,
        organization_id: org.id,
        metadata: %{},
        environment: "test",
        node: "node@test"
      }

      old_log =
        AuditLogSchema.create_changeset(old_log_attrs)
        |> Repo.insert!()

      # Update inserted_at to 2 hours ago
      two_hours_ago =
        DateTime.utc_now() |> DateTime.add(-7200, :second) |> DateTime.truncate(:second)

      Ecto.Changeset.change(old_log, inserted_at: two_hours_ago)
      |> Repo.update!()

      # Create recent log
      create_audit_log("token_generated", user, org)

      {:ok, view, _html} = live(conn, ~p"/dashboard/audit-logs")

      html =
        view
        |> element("form[phx-change='filter_date_range']")
        |> render_change(%{date_range: "1_hour"})

      assert html =~ "Token Generated"
      refute html =~ "Auth Success"
    end

    test "filters by date range - last 24 hours", %{conn: conn, user: user, org: org} do
      create_audit_log("authentication_success", user, org)

      {:ok, view, _html} = live(conn, ~p"/dashboard/audit-logs")

      html =
        view
        |> element("form[phx-change='filter_date_range']")
        |> render_change(%{date_range: "24_hours"})

      assert html =~ "Auth Success"
    end

    test "displays user links", %{conn: conn, user: user, org: org} do
      create_audit_log("authentication_success", user, org)

      {:ok, view, _html} = live(conn, ~p"/dashboard/audit-logs")

      assert has_element?(view, "a[href='/dashboard/users/#{user.id}']", user.email)
    end

    test "displays organization links", %{conn: conn, user: user, org: org} do
      create_audit_log("authentication_success", user, org)

      {:ok, view, _html} = live(conn, ~p"/dashboard/audit-logs")

      assert has_element?(view, "a[href='/dashboard/organizations/#{org.id}']", org.name)
    end

    test "displays IP addresses", %{conn: conn, user: user, org: org} do
      create_audit_log("authentication_success", user, org, %{ip_address: "203.0.113.42"})

      {:ok, _view, html} = live(conn, ~p"/dashboard/audit-logs")

      assert html =~ "203.0.113.42"
    end

    test "displays event badges with correct colors", %{conn: conn, user: user, org: org} do
      create_audit_log("authentication_success", user, org)
      create_audit_log("authentication_failure", user, org)
      create_audit_log("token_generated", user, org)

      {:ok, _view, html} = live(conn, ~p"/dashboard/audit-logs")

      assert html =~ "badge-success"
      assert html =~ "badge-error"
      assert html =~ "badge-info"
    end

    test "displays empty state when no logs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/audit-logs")

      assert html =~ "No audit logs found"
      assert html =~ "Adjust your filters or wait for system activity"
    end

    test "limits to 100 entries", %{conn: conn, user: user, org: org} do
      # Create 150 audit logs
      for _ <- 1..150 do
        create_audit_log("authentication_success", user, org)
      end

      {:ok, view, _html} = live(conn, ~p"/dashboard/audit-logs")

      # Count table rows (should be 100)
      html = render(view)
      # subtract 2 for thead tr and initial
      row_count = html |> String.split("<tr>") |> length() |> Kernel.-(2)

      assert row_count <= 100
    end

    test "displays N/A for logs without user", %{conn: conn, org: org} do
      create_audit_log("authentication_failure", nil, org)

      {:ok, _view, html} = live(conn, ~p"/dashboard/audit-logs")

      assert html =~ "N/A"
    end

    test "displays metadata", %{conn: conn, user: user, org: org} do
      metadata = %{reason: "invalid_password", attempts: 3}
      create_audit_log("authentication_failure", user, org, %{metadata: metadata})

      {:ok, _view, html} = live(conn, ~p"/dashboard/audit-logs")

      assert html =~ "reason"
      assert html =~ "invalid_password"
    end
  end

  # Helper functions

  defp create_user(org, email, name) do
    password_hash = Bcrypt.hash_pwd_salt("password123")

    UserSchema.create_changeset(%{
      email: email,
      name: name,
      password_hash: password_hash,
      status: :active,
      organization_id: org.id
    })
    |> Repo.insert!()
  end

  defp create_audit_log(event_type, user, org, extra_attrs \\ %{}) do
    base_attrs = %{
      event_type: event_type,
      user_id: user && user.id,
      organization_id: org && org.id,
      metadata: Map.get(extra_attrs, :metadata, %{}),
      ip_address: Map.get(extra_attrs, :ip_address, "127.0.0.1"),
      user_agent: Map.get(extra_attrs, :user_agent, "Test User Agent"),
      environment: "test",
      node: "test@localhost"
    }

    AuditLogSchema.create_changeset(base_attrs)
    |> Repo.insert!()
  end
end
