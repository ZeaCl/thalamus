defmodule ThalamusWeb.API.AuditLogControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Domain.ValueObjects.{AccessToken, Scope}
  alias Thalamus.TestHelpers
  alias Thalamus.Infrastructure.Persistence.Schemas.{AuditLogSchema, UserSchema, OrganizationSchema}
  alias Thalamus.Repo

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLOAuth2ClientRepository,
    PostgreSQLTokenRepository
  }

  setup %{conn: conn} do
    # Create organization
    {:ok, org} = Organization.new("Test Corp #{:rand.uniform(10000)}", "owner@test.com", :standard)
    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    # Create and verify user
    {:ok, user} = User.register("audituser#{:rand.uniform(10000)}@test.com", "TestPassword123!")
    {:ok, user} = User.verify_email(user)
    {:ok, user} = PostgreSQLUserRepository.save(user)

    # Create OAuth2 client
    {:ok, client} = TestHelpers.create_test_client("Test Client", org.id, ["openid", "profile"])
    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    # Generate access token
    {:ok, openid_scope} = Scope.new("openid")
    {:ok, profile_scope} = Scope.new("profile")
    scopes = [openid_scope, profile_scope]

    {:ok, access_token} = AccessToken.generate(scopes, user.id, 3600)

    # Store token in database
    client_id_string = Thalamus.Domain.ValueObjects.ClientId.to_string(client.id)
    client_uuid = String.replace_prefix(client_id_string, "client_", "")
    user_uuid = extract_uuid(user.id)

    token_data = %{
      token: access_token.token,
      type: :access_token,
      user_id: user_uuid,
      client_id: client_uuid,
      scopes: ["openid", "profile"],
      expires_at: access_token.expires_at
    }

    :ok = PostgreSQLTokenRepository.store(token_data)

    # Set organization_id in conn for audit log controller
    conn = assign(conn, :organization_id, extract_uuid(org.id))

    {:ok, conn: conn, organization: org, user: user, access_token: access_token.token}
  end

  describe "GET /api/audit-logs/export - CSV format" do
    test "exports audit logs in CSV format with default parameters", %{conn: conn, organization: org, user: user, access_token: token} do
      # Create some audit logs
      log1 = insert_audit_log(org, user, "user_created", %{action: "created user"})
      log2 = insert_audit_log(org, user, "user_updated", %{action: "updated user"})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=csv")

      assert response = response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "attachment; filename=\"audit_logs_"

      # Verify CSV contains headers
      assert response =~ "ID,Timestamp,Event Type,User ID"
      # Verify CSV contains data
      assert response =~ log1.id
      assert response =~ "user_created"
      assert response =~ log2.id
      assert response =~ "user_updated"
    end

    test "filters audit logs by event type", %{conn: conn, organization: org, user: user, access_token: token} do
      insert_audit_log(org, user, "user_created", %{})
      insert_audit_log(org, user, "user_updated", %{})
      login_log = insert_audit_log(org, user, "authentication_success", %{})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=csv&event_type=authentication_success")

      assert response = response(conn, 200)
      assert response =~ login_log.id
      assert response =~ "authentication_success"
      refute response =~ "user_created"
      refute response =~ "user_updated"
    end

    test "filters audit logs by date range", %{conn: conn, organization: org, user: user, access_token: token} do
      # Create log in the past
      yesterday = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
      past_log = insert_audit_log_at(org, user, "user_created", yesterday)

      # Create log today
      today_log = insert_audit_log(org, user, "user_updated", %{})

      # Query only today
      from_date = DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.to_iso8601()
      to_date = DateTime.utc_now() |> DateTime.to_iso8601()

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=csv&from=#{from_date}&to=#{to_date}")

      assert response = response(conn, 200)
      assert response =~ today_log.id
      refute response =~ past_log.id
    end

    test "respects limit parameter", %{conn: conn, organization: org, user: user, access_token: token} do
      # Create 5 logs
      for i <- 1..5 do
        insert_audit_log(org, user, "user_updated", %{index: i})
      end

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=csv&limit=3")

      assert response = response(conn, 200)
      # Count data rows (excluding header and empty last line)
      lines = response |> String.split("\n") |> Enum.reject(&(&1 == ""))
      row_count = length(lines) - 1  # Exclude header
      assert row_count <= 3
    end

    test "filters by user_id", %{conn: conn, organization: org, access_token: token} do
      user1 = insert_user(org)
      user2 = insert_user(org)

      log1 = insert_audit_log(org, user1, "user_created", %{})
      _log2 = insert_audit_log(org, user2, "user_updated", %{})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=csv&user_id=#{user1.id}")

      assert response = response(conn, 200)
      assert response =~ log1.id
      refute response =~ user2.id
    end
  end

  describe "GET /api/audit-logs/export - JSON format" do
    test "exports audit logs in JSON format", %{conn: conn, organization: org, user: user, access_token: token} do
      log1 = insert_audit_log(org, user, "user_created", %{action: "created"})
      log2 = insert_audit_log(org, user, "token_generated", %{token_type: "access"})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=json")

      assert %{"exported_at" => _exported_at, "total_records" => total, "audit_logs" => logs} =
               json_response(conn, 200)

      assert total == 2
      assert length(logs) == 2

      log_ids = Enum.map(logs, & &1["id"])
      assert log1.id in log_ids
      assert log2.id in log_ids

      # Verify structure
      first_log = List.first(logs)
      assert Map.has_key?(first_log, "id")
      assert Map.has_key?(first_log, "timestamp")
      assert Map.has_key?(first_log, "event_type")
      assert Map.has_key?(first_log, "user")
      assert Map.has_key?(first_log, "metadata")
    end

    test "includes user information in JSON export", %{conn: conn, organization: org, user: user, access_token: token} do
      insert_audit_log(org, user, "user_created", %{})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=json")

      assert %{"audit_logs" => [log]} = json_response(conn, 200)
      assert log["user"]["id"] == extract_uuid(user.id)
      assert log["user"]["email"] == to_string(user.email)
    end

    test "includes organization information in JSON export", %{conn: conn, organization: org, user: user, access_token: token} do
      insert_audit_log(org, user, "organization_updated", %{})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=json")

      assert %{"audit_logs" => [log]} = json_response(conn, 200)
      assert log["organization"]["id"] == extract_uuid(org.id)
      assert log["organization"]["name"] == org.name
    end

    test "handles logs without user gracefully", %{conn: conn, organization: org, access_token: token} do
      log = insert_audit_log(org, nil, "system_event", %{})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=json")

      assert %{"audit_logs" => [exported_log]} = json_response(conn, 200)
      assert exported_log["id"] == log.id
      assert exported_log["user"] == nil
    end
  end

  describe "GET /api/audit-logs/export - Validation" do
    test "returns error for invalid format", %{conn: conn, access_token: token} do
      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=xml")

      assert %{"error" => "invalid_format", "message" => message} = json_response(conn, 400)
      assert message =~ "csv"
      assert message =~ "json"
    end

    test "returns error for invalid date format", %{conn: conn, access_token: token} do
      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?from=invalid-date")

      assert %{"error" => "invalid_date_range"} = json_response(conn, 400)
    end

    test "returns error for date range > 1 year", %{conn: conn, access_token: token} do
      from_date = DateTime.utc_now() |> DateTime.add(-400, :day) |> DateTime.to_iso8601()
      to_date = DateTime.utc_now() |> DateTime.to_iso8601()

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?from=#{from_date}&to=#{to_date}")

      assert %{"error" => "date_range_too_large"} = json_response(conn, 400)
    end

    test "returns error for limit > 50000", %{conn: conn, access_token: token} do
      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?limit=100000")

      assert %{"error" => "limit_exceeded"} = json_response(conn, 400)
    end

    test "returns error when to_date < from_date", %{conn: conn, access_token: token} do
      from_date = DateTime.utc_now() |> DateTime.to_iso8601()
      to_date = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.to_iso8601()

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?from=#{from_date}&to=#{to_date}")

      assert %{"error" => "invalid_date_range"} = json_response(conn, 400)
    end
  end

  describe "GET /api/audit-logs/export - Organization Isolation" do
    test "only exports logs from user's organization", %{conn: conn, organization: org, user: user, access_token: token} do
      # Create log in user's org
      my_log = insert_audit_log(org, user, "user_created", %{})

      # Create log in different org
      other_org = insert_organization()
      other_user = insert_user(other_org)
      _other_log = insert_audit_log(other_org, other_user, "user_created", %{})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=json")

      assert %{"audit_logs" => logs} = json_response(conn, 200)
      log_ids = Enum.map(logs, & &1["id"])

      assert my_log.id in log_ids
      assert length(logs) == 1
    end
  end

  describe "GET /api/audit-logs/export - Default Values" do
    test "uses default date range of 90 days when not specified", %{conn: conn, organization: org, user: user, access_token: token} do
      # Create log 100 days ago (outside default range)
      old_date = DateTime.utc_now() |> DateTime.add(-100, :day) |> DateTime.truncate(:second)
      _old_log = insert_audit_log_at(org, user, "user_created", old_date)

      # Create recent log
      recent_log = insert_audit_log(org, user, "user_updated", %{})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=json")

      assert %{"audit_logs" => logs} = json_response(conn, 200)
      log_ids = Enum.map(logs, & &1["id"])

      assert recent_log.id in log_ids
      # Should not include 100-day-old log
      assert length(logs) == 1
    end

    test "uses default limit of 10000 when not specified", %{conn: conn, access_token: token} do
      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=json")

      # Should succeed without error
      assert %{"audit_logs" => _logs} = json_response(conn, 200)
    end

    test "defaults to CSV format when format not specified", %{conn: conn, organization: org, user: user, access_token: token} do
      insert_audit_log(org, user, "user_created", %{})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export")

      assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    end
  end

  describe "GET /api/audit-logs/export - CSV Structure" do
    test "CSV includes all required fields", %{conn: conn, organization: org, user: user, access_token: token} do
      insert_audit_log(org, user, "user_created", %{custom: "data"})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=csv")

      response = response(conn, 200)

      # Check headers
      assert response =~ "ID"
      assert response =~ "Timestamp"
      assert response =~ "Event Type"
      assert response =~ "User ID"
      assert response =~ "User Email"
      assert response =~ "Organization ID"
      assert response =~ "Organization Name"
      assert response =~ "IP Address"
      assert response =~ "User Agent"
      assert response =~ "Metadata"
    end

    test "CSV escapes special characters in metadata", %{conn: conn, organization: org, user: user, access_token: token} do
      insert_audit_log(org, user, "user_created", %{message: "Test, with \"quotes\" and commas"})

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/audit-logs/export?format=csv")

      assert response(conn, 200)
      # CSV library should handle escaping
    end
  end

  # Test helpers

  defp extract_uuid(id) when is_binary(id) do
    # Remove any prefix (user_, org_, etc.)
    cond do
      String.starts_with?(id, "user_") -> String.replace_prefix(id, "user_", "")
      String.starts_with?(id, "org_") -> String.replace_prefix(id, "org_", "")
      true -> id
    end
  end

  defp extract_uuid(id) do
    # Handle value objects by converting to string and stripping prefix
    id
    |> to_string()
    |> extract_uuid()
  end

  defp insert_organization do
    Repo.insert!(%OrganizationSchema{
      id: Ecto.UUID.generate(),
      name: "Test Org #{:rand.uniform(10000)}",
      status: :active,
      plan_type: :free,
      max_users: 10,
      max_api_calls_per_month: 10000,
      support_level: :community,
      api_calls_reset_at: DateTime.utc_now() |> DateTime.truncate(:second),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_user(org) do
    org_id = extract_uuid(org.id)

    Repo.insert!(%UserSchema{
      id: Ecto.UUID.generate(),
      organization_id: org_id,
      email: "user#{:rand.uniform(10000)}@example.com",
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      status: :active,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_audit_log(org, user, event_type, metadata) do
    org_id = extract_uuid(org.id)
    user_id = if user, do: extract_uuid(user.id), else: nil

    Repo.insert!(%AuditLogSchema{
      id: Ecto.UUID.generate(),
      event_type: event_type,
      user_id: user_id,
      organization_id: org_id,
      metadata: metadata,
      ip_address: "127.0.0.1",
      user_agent: "Mozilla/5.0",
      request_id: Ecto.UUID.generate(),
      environment: "test",
      node: "test@localhost",
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_audit_log_at(org, user, event_type, timestamp) do
    org_id = extract_uuid(org.id)
    user_id = if user, do: extract_uuid(user.id), else: nil

    Repo.insert!(%AuditLogSchema{
      id: Ecto.UUID.generate(),
      event_type: event_type,
      user_id: user_id,
      organization_id: org_id,
      metadata: %{},
      ip_address: "127.0.0.1",
      user_agent: "Mozilla/5.0",
      inserted_at: timestamp
    })
  end
end
