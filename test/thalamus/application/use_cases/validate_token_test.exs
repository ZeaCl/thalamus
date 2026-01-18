defmodule Thalamus.Application.UseCases.ValidateTokenTest do
  use ExUnit.Case, async: true

  import Mox

  alias Thalamus.Application.UseCases.ValidateToken
  alias Thalamus.Domain.ValueObjects.{UserId, ClientId}

  setup :verify_on_exit!

  describe "execute/2 - valid tokens" do
    test "validates active access token" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_valid_token_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid", "profile"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_valid_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_valid_token_123", deps)

      assert result.valid == true
      assert result.active == true
      assert result.scope == ["openid", "profile"]
      assert result.client_id == "test_client_123"
      assert result.user_id == to_string(user_id)
      assert result.exp == token_data.expires_at
      assert result.iat == token_data.created_at
      assert result.revoked == false
      assert result.expired == false
    end

    test "validates token without user (client_credentials)" do
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_client_token_123",
        type: :access_token,
        user_id: nil,
        client_id: client_id,
        organization_id: nil,
        scopes: ["api:read", "api:write"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_client_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_client_token_123", deps)

      assert result.valid == true
      assert result.active == true
      assert result.scope == ["api:read", "api:write"]
      assert result.client_id == "test_client_123"
      assert is_nil(result.user_id)
    end

    test "validates token with empty scopes" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_no_scopes_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: [],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_no_scopes_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_no_scopes_123", deps)

      assert result.valid == true
      assert result.active == true
      assert result.scope == []
    end
  end

  describe "execute/2 - invalid tokens" do
    test "returns invalid result for non-existent token" do
      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_nonexistent_123" ->
        {:error, :not_found}
      end)

      {:ok, result} = ValidateToken.execute("at_nonexistent_123", deps)

      assert result.valid == false
      assert result.active == false
      assert result.scope == []
      assert is_nil(result.client_id)
      assert is_nil(result.user_id)
      assert is_nil(result.exp)
      assert is_nil(result.iat)
    end

    test "returns invalid result for revoked token" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_revoked_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: true,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_revoked_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_revoked_123", deps)

      assert result.valid == false
      assert result.active == false
      assert result.revoked == true
      assert result.expired == false
    end

    test "returns invalid result for expired token" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_expired_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        revoked: false,
        created_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_expired_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_expired_123", deps)

      assert result.valid == false
      assert result.active == false
      assert result.revoked == false
      assert result.expired == true
    end

    test "returns invalid result for both revoked and expired token" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_revoked_expired_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        revoked: true,
        created_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_revoked_expired_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_revoked_expired_123", deps)

      assert result.valid == false
      assert result.active == false
      assert result.revoked == true
      assert result.expired == true
    end

    test "returns error for invalid token format (non-string)" do
      deps = %{
        token_repository: MockTokenRepository
      }

      {:error, :invalid_token_format} = ValidateToken.execute(123, deps)
      {:error, :invalid_token_format} = ValidateToken.execute(nil, deps)
      {:error, :invalid_token_format} = ValidateToken.execute(%{}, deps)
    end
  end

  describe "execute_with_scope/3 - scope validation" do
    test "validates token with required single scope" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_valid_token_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid", "profile", "email"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_valid_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute_with_scope("at_valid_token_123", "openid", deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == true
    end

    test "validates token with required multiple scopes" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_valid_token_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid", "profile", "email"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_valid_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} =
        ValidateToken.execute_with_scope("at_valid_token_123", "openid profile", deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == true
    end

    test "rejects token missing required scope" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_limited_token_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid", "profile"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_limited_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute_with_scope("at_limited_token_123", "admin", deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == false
    end

    test "rejects token missing one of multiple required scopes" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_limited_token_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid", "profile"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_limited_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} =
        ValidateToken.execute_with_scope("at_limited_token_123", "openid profile email", deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == false
    end

    test "validates inactive token correctly shows missing scope" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_expired_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_expired_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute_with_scope("at_expired_123", "openid profile", deps)

      assert result.valid == false
      assert result.active == false
      assert result.has_required_scope == false
    end

    test "handles empty scope string" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_valid_token_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_valid_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute_with_scope("at_valid_token_123", "", deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == true
    end
  end

  describe "execute_with_scope/3 - edge cases" do
    test "handles token not found with scope check" do
      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_nonexistent_123" ->
        {:error, :not_found}
      end)

      {:ok, result} = ValidateToken.execute_with_scope("at_nonexistent_123", "openid", deps)

      assert result.valid == false
      assert result.active == false
      assert result.has_required_scope == false
    end

    test "validates token with exact scope match" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_exact_match_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid", "profile"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_exact_match_123" ->
        {:ok, token_data}
      end)

      {:ok, result} =
        ValidateToken.execute_with_scope("at_exact_match_123", "openid profile", deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == true
    end

    test "validates token with subset of scopes" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_superset_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid", "profile", "email", "phone"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_superset_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute_with_scope("at_superset_123", "openid email", deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == true
    end
  end

  describe "execute/2 - agent token fields" do
    test "validates agent token with all agent-specific fields" do
      {:ok, user_id} = UserId.generate()
      {:ok, delegated_by} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_agent_token_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid", "profile"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now(),
        # Agent-specific fields
        agent_type: "autonomous",
        delegated_by_user_id: delegated_by,
        delegation_chain: [to_string(delegated_by), to_string(user_id)],
        task_id: "task_123",
        task_type: "data_analysis",
        task_scopes: ["data:read", "data:analyze"],
        max_operations: 100,
        operations_count: 25,
        expires_on_completion: true,
        intent_description: "Analyze sales data for Q4",
        orchestrator_id: "orchestrator_456",
        environment: "production"
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_agent_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_agent_token_123", deps)

      assert result.valid == true
      assert result.active == true
      assert result.agent_type == "autonomous"
      assert result.delegated_by == to_string(delegated_by)
      assert result.delegation_chain == [to_string(delegated_by), to_string(user_id)]
      assert result.delegation_depth == 2
      assert result.task_id == "task_123"
      assert result.task_type == "data_analysis"
      assert result.task_scopes == ["data:read", "data:analyze"]
      assert result.max_operations == 100
      assert result.operations_remaining == 75
      assert result.expires_on_completion == true
      assert result.intent_description == "Analyze sales data for Q4"
      assert result.orchestrator_id == "orchestrator_456"
      assert result.environment == "production"
    end

    test "validates agent token with no operations remaining" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_exhausted_token_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now(),
        max_operations: 50,
        operations_count: 50
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_exhausted_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_exhausted_token_123", deps)

      assert result.max_operations == 50
      assert result.operations_remaining == 0
    end

    test "validates agent token with operations exceeded (negative handling)" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_over_limit_token_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now(),
        max_operations: 10,
        operations_count: 15
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_over_limit_token_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_over_limit_token_123", deps)

      assert result.max_operations == 10
      assert result.operations_remaining == 0
    end

    test "validates token without delegation chain field (missing key)" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_no_delegation_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
        # delegation_chain key is not present
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_no_delegation_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_no_delegation_123", deps)

      assert result.delegation_chain == []
      assert result.delegation_depth == 0
    end

    test "validates token with empty delegation chain list" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_empty_chain_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now(),
        delegation_chain: []
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_empty_chain_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_empty_chain_123", deps)

      assert result.delegation_chain == []
      assert result.delegation_depth == 0
    end

    test "validates token with integer user IDs in delegation chain" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_integer_chain_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now(),
        delegation_chain: [123, 456],
        delegated_by_user_id: 789
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_integer_chain_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_integer_chain_123", deps)

      assert result.delegation_chain == ["123", "456"]
      assert result.delegation_depth == 2
      assert result.delegated_by == "789"
    end

    test "validates token with nil delegated_by_user_id" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_no_delegator_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now(),
        delegated_by_user_id: nil
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_no_delegator_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_no_delegator_123", deps)

      assert result.delegated_by == nil
    end

    test "validates token without max_operations (unlimited)" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_unlimited_ops_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now(),
        max_operations: nil,
        operations_count: 100
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_unlimited_ops_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_unlimited_ops_123", deps)

      assert result.max_operations == nil
      assert result.operations_remaining == nil
    end

    test "validates token without operations_count field" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_no_op_count_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now(),
        max_operations: 50
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_no_op_count_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_no_op_count_123", deps)

      assert result.max_operations == 50
      assert result.operations_remaining == nil
    end
  end

  describe "execute/2 - organization_id handling" do
    test "validates token with organization_id" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_with_org_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: Ecto.UUID.generate(),
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_with_org_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_with_org_123", deps)

      assert result.valid == true
      assert result.organization_id == token_data.organization_id
    end

    test "validates token with nil organization_id" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_no_org_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_no_org_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_no_org_123", deps)

      assert result.valid == true
      assert result.organization_id == nil
    end
  end

  describe "execute/2 - nil scopes handling" do
    test "validates token with nil scopes (converts to empty list)" do
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: "at_nil_scopes_123",
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        organization_id: nil,
        scopes: nil,
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository
      }

      expect(MockTokenRepository, :find, fn "at_nil_scopes_123" ->
        {:ok, token_data}
      end)

      {:ok, result} = ValidateToken.execute("at_nil_scopes_123", deps)

      assert result.valid == true
      assert result.scope == []
    end
  end
end
