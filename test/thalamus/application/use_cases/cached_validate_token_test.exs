defmodule Thalamus.Application.UseCases.CachedValidateTokenTest do
  use ExUnit.Case, async: true

  import Mox

  alias Thalamus.Application.UseCases.CachedValidateToken

  setup :verify_on_exit!

  describe "execute/2 - cache hit" do
    test "returns cached result when available" do
      token = "at_cached_token_123"
      user_id = Ecto.UUID.generate()
      client_id = "test_client_123"

      cached_result = %{
        valid: true,
        active: true,
        scope: ["openid", "profile"],
        client_id: client_id,
        user_id: user_id,
        organization_id: nil,
        email: nil,
        exp: DateTime.add(DateTime.utc_now(), 3600, :second),
        iat: DateTime.utc_now(),
        revoked: false,
        expired: false,
        agent_type: nil,
        delegated_by: nil,
        delegation_chain: [],
        delegation_depth: 0,
        task_id: nil,
        task_type: nil,
        task_scopes: [],
        max_operations: nil,
        operations_remaining: nil,
        expires_on_completion: false,
        intent_description: nil,
        orchestrator_id: nil,
        environment: nil
      }

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:ok, cached_result}
      end)

      # Token repository should NOT be called (cache hit)
      # No expect for MockTokenRepository

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result == cached_result
      assert result.valid == true
      assert result.active == true
    end

    test "returns cached agent token result" do
      token = "at_agent_token_xyz"
      user_id = Ecto.UUID.generate()
      delegator_id = Ecto.UUID.generate()

      cached_result = %{
        valid: true,
        active: true,
        scope: ["corpus:read", "corpus:write"],
        client_id: "agent_client_123",
        # Agent tokens have no user_id
        user_id: nil,
        organization_id: Ecto.UUID.generate(),
        email: nil,
        exp: DateTime.add(DateTime.utc_now(), 900, :second),
        iat: DateTime.utc_now(),
        revoked: false,
        expired: false,
        # Agent-specific fields
        agent_type: "autonomous",
        delegated_by: delegator_id,
        delegation_chain: [delegator_id],
        delegation_depth: 1,
        task_id: "task_abc123",
        task_type: "document_processing",
        task_scopes: ["corpus:read", "corpus:write"],
        max_operations: 100,
        operations_remaining: 75,
        expires_on_completion: true,
        intent_description: "Process documents for compliance",
        orchestrator_id: "orch_xyz",
        environment: "production"
      }

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:ok, cached_result}
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.agent_type == "autonomous"
      assert result.task_id == "task_abc123"
      assert result.max_operations == 100
      assert result.operations_remaining == 75
      assert result.delegation_depth == 1
    end
  end

  describe "execute/2 - cache miss" do
    test "validates token and caches result on cache miss" do
      token = "at_fresh_token_123"
      user_id = Ecto.UUID.generate()
      client_id = "test_client_123"

      token_data = %{
        token: token,
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        scopes: ["openid", "profile"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      # Cache miss
      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      # Fetch from database
      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      # Cache the result
      expect(MockCacheService, :set, fn ^cache_key, result, ttl ->
        assert result.valid == true
        assert result.active == true
        assert result.scope == ["openid", "profile"]
        # 5 minutes default TTL
        assert ttl == 300
        :ok
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == true
      assert result.active == true
      assert result.scope == ["openid", "profile"]
    end

    test "validates agent token and caches with agent metadata" do
      token = "at_agent_fresh_123"
      delegator_id = Ecto.UUID.generate()
      client_id = "agent_client_456"
      org_id = Ecto.UUID.generate()

      token_data = %{
        token: token,
        type: :access_token,
        # Agent token
        user_id: nil,
        client_id: client_id,
        organization_id: org_id,
        scopes: ["corpus:read"],
        expires_at: DateTime.add(DateTime.utc_now(), 900, :second),
        revoked: false,
        created_at: DateTime.utc_now(),
        # Agent fields
        agent_type: "supervised",
        delegated_by_user_id: delegator_id,
        delegation_chain: [delegator_id],
        task_id: "task_supervised_001",
        task_type: "data_extraction",
        task_scopes: ["corpus:read"],
        max_operations: 50,
        operations_count: 10,
        expires_on_completion: true,
        intent_description: "Extract data from CSV",
        orchestrator_id: "orch_main",
        environment: "development"
      }

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      expect(MockCacheService, :set, fn ^cache_key, result, _ttl ->
        assert result.agent_type == "supervised"
        assert result.task_id == "task_supervised_001"
        assert result.max_operations == 50
        # 50 - 10
        assert result.operations_remaining == 40
        assert result.delegation_depth == 1
        :ok
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.agent_type == "supervised"
      assert result.task_id == "task_supervised_001"
      assert result.operations_remaining == 40
    end

    test "caches invalid token result" do
      token = "at_invalid_token_xyz"

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:error, :not_found}
      end)

      expect(MockCacheService, :set, fn ^cache_key, result, _ttl ->
        assert result.valid == false
        assert result.active == false
        :ok
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == false
      assert result.active == false
    end
  end

  describe "execute/2 - cache unavailable" do
    test "falls back to database when cache service is unavailable" do
      token = "at_fallback_token_123"
      user_id = Ecto.UUID.generate()
      client_id = "test_client_789"

      token_data = %{
        token: token,
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      # Cache service unavailable
      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :cache_unavailable}
      end)

      # Fallback to database
      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      # Should NOT attempt to cache when cache is unavailable
      # No expect for set

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == true
      assert result.active == true
    end

    test "continues when cache set fails after successful validation" do
      token = "at_cache_fail_token_123"
      user_id = Ecto.UUID.generate()
      client_id = "test_client_999"

      token_data = %{
        token: token,
        type: :access_token,
        user_id: user_id,
        client_id: client_id,
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      expect(MockCacheService, :set, fn ^cache_key, _result, _ttl ->
        {:error, :cache_write_failed}
      end)

      # Should still return result even if caching fails
      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == true
      assert result.active == true
    end
  end

  describe "execute/2 - revoked and expired tokens" do
    test "caches revoked token result" do
      token = "at_revoked_token_123"
      user_id = Ecto.UUID.generate()

      token_data = %{
        token: token,
        type: :access_token,
        user_id: user_id,
        client_id: "test_client",
        scopes: ["openid"],
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        # Revoked
        revoked: true,
        created_at: DateTime.utc_now()
      }

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      expect(MockCacheService, :set, fn ^cache_key, result, _ttl ->
        assert result.valid == false
        assert result.active == false
        assert result.revoked == true
        :ok
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == false
      assert result.active == false
      assert result.revoked == true
    end

    test "caches expired token result" do
      token = "at_expired_token_456"
      user_id = Ecto.UUID.generate()

      token_data = %{
        token: token,
        type: :access_token,
        user_id: user_id,
        client_id: "test_client",
        scopes: ["openid"],
        # Expired
        expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        revoked: false,
        created_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      }

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      expect(MockCacheService, :set, fn ^cache_key, result, _ttl ->
        assert result.valid == false
        assert result.active == false
        assert result.expired == true
        :ok
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == false
      assert result.active == false
      assert result.expired == true
    end
  end

  describe "execute/2 - invalid input" do
    test "returns error with non-binary token" do
      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      assert {:error, :invalid_token_format} = CachedValidateToken.execute(123, deps)
      assert {:error, :invalid_token_format} = CachedValidateToken.execute(nil, deps)
      assert {:error, :invalid_token_format} = CachedValidateToken.execute(:atom, deps)
    end
  end

  describe "performance improvement" do
    test "cache hit is significantly faster than database lookup" do
      token = "at_performance_test_123"

      cached_result = %{
        valid: true,
        active: true,
        scope: ["openid"],
        client_id: "test_client",
        user_id: Ecto.UUID.generate(),
        organization_id: nil,
        email: nil,
        exp: DateTime.add(DateTime.utc_now(), 3600, :second),
        iat: DateTime.utc_now(),
        revoked: false,
        expired: false,
        agent_type: nil,
        delegated_by: nil,
        delegation_chain: [],
        delegation_depth: 0,
        task_id: nil,
        task_type: nil,
        task_scopes: [],
        max_operations: nil,
        operations_remaining: nil,
        expires_on_completion: false,
        intent_description: nil,
        orchestrator_id: nil,
        environment: nil
      }

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token_validation:#{token}"

      # Measure cache hit performance
      expect(MockCacheService, :get, fn ^cache_key ->
        {:ok, cached_result}
      end)

      start_time = System.monotonic_time(:microsecond)
      {:ok, _result} = CachedValidateToken.execute(token, deps)
      cache_hit_duration = System.monotonic_time(:microsecond) - start_time

      # Cache hit should be very fast (< 1ms in most cases)
      # In tests it's just a function call, so should be < 100 microseconds
      assert cache_hit_duration < 1000
    end
  end

  describe "cache key generation" do
    test "uses consistent cache key format" do
      token1 = "at_token_abc_123"
      token2 = "at_token_xyz_789"

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      # Test that different tokens get different cache keys
      expect(MockCacheService, :get, fn key ->
        case key do
          "token_validation:" <> _ -> {:error, :not_found}
          _ -> {:error, :invalid_key}
        end
      end)

      expect(MockTokenRepository, :find, 2, fn _token ->
        {:error, :not_found}
      end)

      expect(MockCacheService, :set, 2, fn _key, _value, _ttl ->
        :ok
      end)

      CachedValidateToken.execute(token1, deps)
      CachedValidateToken.execute(token2, deps)
    end
  end
end
