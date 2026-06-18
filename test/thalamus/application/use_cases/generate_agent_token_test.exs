defmodule Thalamus.Application.UseCases.GenerateAgentTokenTest do
  use ExUnit.Case, async: false

  import Mox

  alias Thalamus.Application.UseCases.GenerateAgentToken
  alias Thalamus.Application.DTOs.{AgentTokenRequest, AgentTokenResponse}

  setup :verify_on_exit!

  describe "execute/2 - successful agent token generation" do
    test "generates autonomous agent token with minimal parameters" do
      client_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        is_active: true,
        allowed_scopes: ["corpus:read"],
        organization_id: org_id
      }

      delegator = %{
        id: user_id,
        is_active: true
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: user_id,
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, delegator}
      end)

      # Mock GetEffectiveScopes dependencies
      expect(MockCacheService, :get, fn _cache_key ->
        {:error, :not_found}
      end)

      expect(MockRoleRepository, :get_user_roles, fn _user_id ->
        {:ok, []}
      end)

      expect(MockTokenRepository, :store, fn token_data ->
        assert String.starts_with?(token_data.token, "at_")
        assert token_data.agent_type == "autonomous"
        assert token_data.delegated_by_user_id == user_id
        assert token_data.delegation_chain == [user_id]
        assert token_data.task_scopes == ["corpus:read"]
        assert token_data.client_id == client_id
        assert token_data.organization_id == org_id
        assert is_nil(token_data.user_id)
        {:ok, token_data}
      end)

      expect(MockAuditLogger, :log, fn event ->
        assert event.event_type == "agent_token_generated"
        assert event.user_id == user_id
        assert event.organization_id == org_id
        :ok
      end)

      assert {:ok, %AgentTokenResponse{} = response} = GenerateAgentToken.execute(request, deps)

      assert String.starts_with?(response.access_token, "at_")
      assert response.token_type == "Bearer"
      # Default TTL
      assert response.expires_in == 900
      assert response.scope == "corpus:read"
      assert response.agent_type == "autonomous"
      assert response.expires_on_completion == false
    end

    test "generates supervisor agent token with all optional parameters" do
      client_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        is_active: true,
        allowed_scopes: ["corpus:read", "corpus:write", "api:read"],
        organization_id: org_id
      }

      delegator = %{
        id: user_id,
        is_active: true
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: user_id,
        agent_type: "supervisor",
        task_scopes: ["corpus:read", "corpus:write"],
        task_id: "task_abc123",
        task_type: "document_processing",
        max_operations: 100,
        expires_on_completion: true,
        intent_description: "Process uploaded documents for compliance",
        orchestrator_id: "orch_xyz789",
        ttl: 1800
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, delegator}
      end)

      # Mock GetEffectiveScopes dependencies
      expect(MockCacheService, :get, fn _cache_key ->
        {:error, :not_found}
      end)

      expect(MockRoleRepository, :get_user_roles, fn _user_id ->
        {:ok, []}
      end)

      expect(MockTokenRepository, :store, fn token_data ->
        assert token_data.agent_type == "supervisor"
        assert token_data.task_id == "task_abc123"
        assert token_data.task_type == "document_processing"
        assert token_data.task_scopes == ["corpus:read", "corpus:write"]
        assert token_data.max_operations == 100
        assert token_data.operations_count == 0
        assert token_data.expires_on_completion == true
        assert token_data.intent_description == "Process uploaded documents for compliance"
        assert token_data.orchestrator_id == "orch_xyz789"
        assert token_data.expires_in == 1800
        {:ok, token_data}
      end)

      expect(MockAuditLogger, :log, fn event ->
        assert event.metadata.task_id == "task_abc123"
        assert event.metadata.max_operations == 100
        :ok
      end)

      assert {:ok, response} = GenerateAgentToken.execute(request, deps)

      assert response.agent_type == "supervisor"
      assert response.task_id == "task_abc123"
      assert response.max_operations == 100
      assert response.expires_on_completion == true
      assert response.expires_in == 1800
    end

    test "generates tool agent token with short TTL" do
      client_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        is_active: true,
        allowed_scopes: ["api:read"],
        organization_id: org_id
      }

      delegator = %{
        id: user_id,
        is_active: true
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: user_id,
        agent_type: "tool",
        task_scopes: ["api:read"],
        task_id: "tool_task_001",
        max_operations: 10,
        expires_on_completion: true,
        ttl: 300
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, delegator}
      end)

      # Mock GetEffectiveScopes dependencies
      expect(MockCacheService, :get, fn _cache_key ->
        {:error, :not_found}
      end)

      expect(MockRoleRepository, :get_user_roles, fn _user_id ->
        {:ok, []}
      end)

      expect(MockTokenRepository, :store, fn token_data ->
        assert token_data.agent_type == "tool"
        assert token_data.max_operations == 10
        assert token_data.expires_on_completion == true
        assert token_data.expires_in == 300
        {:ok, token_data}
      end)

      expect(MockAuditLogger, :log, fn _event -> :ok end)

      assert {:ok, response} = GenerateAgentToken.execute(request, deps)

      assert response.agent_type == "tool"
      assert response.expires_in == 300
    end

    test "enforces maximum TTL of 3600 seconds" do
      client_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        is_active: true,
        allowed_scopes: ["corpus:read"],
        organization_id: org_id
      }

      delegator = %{
        id: user_id,
        is_active: true
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: user_id,
        agent_type: "autonomous",
        task_scopes: ["corpus:read"],
        # Request 2 hours
        ttl: 7200
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, delegator}
      end)

      # Mock GetEffectiveScopes dependencies
      expect(MockCacheService, :get, fn _cache_key ->
        {:error, :not_found}
      end)

      expect(MockRoleRepository, :get_user_roles, fn _user_id ->
        {:ok, []}
      end)

      expect(MockTokenRepository, :store, fn token_data ->
        # TTL should be capped at 3600
        assert token_data.expires_in == 3600
        {:ok, token_data}
      end)

      expect(MockAuditLogger, :log, fn _event -> :ok end)

      assert {:ok, response} = GenerateAgentToken.execute(request, deps)
      # Capped at maximum
      assert response.expires_in == 3600
    end
  end

  describe "execute/2 - validation errors" do
    test "fails with missing client_id" do
      request = %AgentTokenRequest{
        client_id: nil,
        client_secret: "test_secret",
        delegated_by_user_id: Ecto.UUID.generate(),
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      assert {:error, :missing_client_id} = GenerateAgentToken.execute(request, deps)
    end

    test "fails with missing client_secret" do
      request = %AgentTokenRequest{
        client_id: Ecto.UUID.generate(),
        client_secret: nil,
        delegated_by_user_id: Ecto.UUID.generate(),
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      assert {:error, :missing_client_secret} = GenerateAgentToken.execute(request, deps)
    end

    test "fails with missing delegated_by_user_id" do
      request = %AgentTokenRequest{
        client_id: Ecto.UUID.generate(),
        client_secret: "test_secret",
        delegated_by_user_id: nil,
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      assert {:error, :missing_delegated_by_user_id} = GenerateAgentToken.execute(request, deps)
    end

    test "fails with missing agent_type" do
      request = %AgentTokenRequest{
        client_id: Ecto.UUID.generate(),
        client_secret: "test_secret",
        delegated_by_user_id: Ecto.UUID.generate(),
        agent_type: nil,
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      assert {:error, :missing_agent_type} = GenerateAgentToken.execute(request, deps)
    end

    test "fails with invalid agent_type" do
      request = %AgentTokenRequest{
        client_id: Ecto.UUID.generate(),
        client_secret: "test_secret",
        delegated_by_user_id: Ecto.UUID.generate(),
        agent_type: "invalid_type",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      assert {:error, :invalid_agent_type} = GenerateAgentToken.execute(request, deps)
    end

    test "fails with empty task_scopes" do
      request = %AgentTokenRequest{
        client_id: Ecto.UUID.generate(),
        client_secret: "test_secret",
        delegated_by_user_id: Ecto.UUID.generate(),
        agent_type: "autonomous",
        task_scopes: []
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      assert {:error, :empty_task_scopes} = GenerateAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - authentication errors" do
    test "fails with non-existent client" do
      client_id = Ecto.UUID.generate()

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: Ecto.UUID.generate(),
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:error, :not_found}
      end)

      assert {:error, :invalid_client} = GenerateAgentToken.execute(request, deps)
    end

    test "fails with invalid client_secret" do
      client_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("correct_secret"),
        is_active: true,
        allowed_scopes: ["corpus:read"],
        organization_id: Ecto.UUID.generate()
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "wrong_secret",
        delegated_by_user_id: Ecto.UUID.generate(),
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      assert {:error, :invalid_client} = GenerateAgentToken.execute(request, deps)
    end

    test "fails with inactive client" do
      client_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        # Inactive
        is_active: false,
        allowed_scopes: ["corpus:read"],
        organization_id: Ecto.UUID.generate()
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: Ecto.UUID.generate(),
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      assert {:error, :client_inactive} = GenerateAgentToken.execute(request, deps)
    end

    test "fails with non-existent delegator" do
      client_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        is_active: true,
        allowed_scopes: ["corpus:read"],
        organization_id: Ecto.UUID.generate()
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: user_id,
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:error, :not_found}
      end)

      assert {:error, :delegator_not_found} = GenerateAgentToken.execute(request, deps)
    end

    test "fails with inactive delegator" do
      client_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        is_active: true,
        allowed_scopes: ["corpus:read"],
        organization_id: Ecto.UUID.generate()
      }

      delegator = %{
        id: user_id,
        # Inactive
        is_active: false
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: user_id,
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, delegator}
      end)

      assert {:error, :delegator_inactive} = GenerateAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - scope validation" do
    test "fails when task_scopes not subset of client allowed_scopes" do
      client_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        is_active: true,
        # Only corpus:read allowed
        allowed_scopes: ["corpus:read"],
        organization_id: Ecto.UUID.generate()
      }

      delegator = %{
        id: user_id,
        is_active: true
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: user_id,
        agent_type: "autonomous",
        # Not allowed
        task_scopes: ["corpus:write", "admin:delete"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, delegator}
      end)

      assert {:error, {:invalid_task_scopes, invalid}} = GenerateAgentToken.execute(request, deps)
      assert "corpus:write" in invalid
      assert "admin:delete" in invalid
    end

    test "allows task_scopes as valid subset of client allowed_scopes" do
      client_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        is_active: true,
        allowed_scopes: ["corpus:read", "corpus:write", "api:read", "zea:write"],
        organization_id: org_id
      }

      delegator = %{
        id: user_id,
        is_active: true
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: user_id,
        agent_type: "autonomous",
        # Valid subset
        task_scopes: ["corpus:read", "api:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, delegator}
      end)

      # Mock GetEffectiveScopes dependencies
      expect(MockCacheService, :get, fn _cache_key ->
        {:error, :not_found}
      end)

      expect(MockRoleRepository, :get_user_roles, fn _user_id ->
        {:ok, []}
      end)

      expect(MockTokenRepository, :store, fn token_data ->
        assert token_data.task_scopes == ["corpus:read", "api:read"]
        {:ok, token_data}
      end)

      expect(MockAuditLogger, :log, fn _event -> :ok end)

      assert {:ok, _response} = GenerateAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - delegation chain" do
    test "creates delegation chain with single delegator" do
      client_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      client = %{
        id: client_id,
        client_secret: Bcrypt.hash_pwd_salt("test_secret"),
        is_active: true,
        allowed_scopes: ["corpus:read"],
        organization_id: org_id
      }

      delegator = %{
        id: user_id,
        is_active: true
      }

      request = %AgentTokenRequest{
        client_id: client_id,
        client_secret: "test_secret",
        delegated_by_user_id: user_id,
        agent_type: "autonomous",
        task_scopes: ["corpus:read"]
      }

      deps = %{
        client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger,
        role_repository: MockRoleRepository,
        cache_service: MockCacheService
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, delegator}
      end)

      # Mock GetEffectiveScopes dependencies
      expect(MockCacheService, :get, fn _cache_key ->
        {:error, :not_found}
      end)

      expect(MockRoleRepository, :get_user_roles, fn _user_id ->
        {:ok, []}
      end)

      expect(MockTokenRepository, :store, fn token_data ->
        # Delegation chain should contain just the delegator
        assert token_data.delegation_chain == [user_id]
        assert token_data.delegated_by_user_id == user_id
        {:ok, token_data}
      end)

      expect(MockAuditLogger, :log, fn _event -> :ok end)

      assert {:ok, _response} = GenerateAgentToken.execute(request, deps)
    end
  end
end
