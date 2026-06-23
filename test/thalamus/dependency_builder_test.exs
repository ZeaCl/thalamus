defmodule Thalamus.DependencyBuilderTest do
  use ExUnit.Case, async: true

  alias Thalamus.DependencyBuilder

  describe "build_default/0" do
    test "returns all required repositories and audit logger" do
      deps = DependencyBuilder.build_default()

      assert Map.has_key?(deps, :client_repository)
      assert Map.has_key?(deps, :user_repository)
      assert Map.has_key?(deps, :agent_token_repository)
      assert Map.has_key?(deps, :organization_repository)
      assert Map.has_key?(deps, :audit_logger)
      refute Map.has_key?(deps, :context)
    end
  end

  describe "build_for_web/1" do
    test "includes context from the connection" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("user-agent", "TestAgent/1.0")

      deps = DependencyBuilder.build_for_web(conn)

      assert Map.has_key?(deps, :context)
      assert deps.context.ip_address == "127.0.0.1"
      assert deps.context.user_agent == "TestAgent/1.0"
      assert deps.context.environment == :dev
    end

    test "extracts x-forwarded-for header when present" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("user-agent", "TestAgent/1.0")
        |> Plug.Conn.put_req_header("x-forwarded-for", "10.0.0.1, 10.0.0.2")

      deps = DependencyBuilder.build_for_web(conn)
      assert deps.context.ip_address == "10.0.0.1"
    end

    test "falls back to remote_ip when no x-forwarded-for header" do
      conn = %{Phoenix.ConnTest.build_conn() | remote_ip: {192, 168, 1, 1}}

      deps = DependencyBuilder.build_for_web(conn)
      assert deps.context.ip_address == "192.168.1.1"
    end

    test "returns unknown when user-agent header is missing" do
      conn = Phoenix.ConnTest.build_conn()

      deps = DependencyBuilder.build_for_web(conn)
      assert deps.context.user_agent == "unknown"
    end
  end

  describe "build_for_cerebelum/0" do
    test "returns same structure as build_default" do
      deps = DependencyBuilder.build_for_cerebelum()

      assert Map.has_key?(deps, :client_repository)
      assert Map.has_key?(deps, :user_repository)
      assert Map.has_key?(deps, :agent_token_repository)
      refute Map.has_key?(deps, :context)
    end
  end

  describe "build_for_tests/0" do
    test "returns mock modules for all dependencies" do
      deps = DependencyBuilder.build_for_tests()

      assert deps.client_repository == Thalamus.MockClientRepository
      assert deps.user_repository == Thalamus.MockUserRepository
      assert deps.agent_token_repository == Thalamus.MockAgentTokenRepository
      assert deps.organization_repository == Thalamus.MockOrganizationRepository
      assert deps.audit_logger == Thalamus.MockAuditLogger
      refute Map.has_key?(deps, :context)
    end
  end
end
