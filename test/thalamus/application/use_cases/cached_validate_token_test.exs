defmodule Thalamus.Application.UseCases.CachedValidateTokenTest do
  use ExUnit.Case, async: false

  import Mox

  alias Thalamus.Application.UseCases.CachedValidateToken
  alias Thalamus.Domain.ValueObjects.{UserId, ClientId}

  setup :verify_on_exit!

  describe "execute/2 - cache hit" do
    test "returns cached result when available" do
      token = "at_cached_token_123"
      {:ok, user_id} = UserId.generate()

      cached_result = %{
        valid: true,
        active: true,
        scope: ["openid", "profile"],
        client_id: "test_client_123",
        user_id: to_string(user_id),
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

      cache_key = "token:introspect:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:ok, cached_result}
      end)

      # Token repository should NOT be called (cache hit)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result == cached_result
      assert result.valid == true
      assert result.active == true
      assert result.scope == ["openid", "profile"]
    end

    test "returns cached invalid token result" do
      token = "at_cached_invalid_123"

      cached_result = %{
        valid: false,
        active: false,
        scope: [],
        client_id: nil,
        user_id: nil,
        organization_id: nil,
        email: nil,
        exp: nil,
        iat: nil,
        revoked: nil,
        expired: nil,
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

      cache_key = "token:introspect:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:ok, cached_result}
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == false
      assert result.active == false
    end
  end

  describe "execute/2 - cache miss" do
    test "validates token and caches result on cache miss" do
      token = "at_fresh_token_123"
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: token,
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
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token:introspect:#{token}"

      # Cache miss
      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      # Fetch from database
      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      # Note: Cache set happens in async task, so we can't easily verify it
      # Just verify the function returns correct result

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == true
      assert result.active == true
      assert result.scope == ["openid", "profile"]
      assert result.client_id == "test_client_123"
      assert result.user_id == to_string(user_id)

      # Give async task time to complete
      Process.sleep(50)
    end

    test "validates and caches invalid token result" do
      token = "at_invalid_token_xyz"

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token:introspect:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:error, :not_found}
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == false
      assert result.active == false

      Process.sleep(50)
    end

    test "validates revoked token and caches result" do
      token = "at_revoked_token_123"
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client")

      token_data = %{
        token: token,
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
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token:introspect:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == false
      assert result.active == false
      assert result.revoked == true

      Process.sleep(50)
    end

    test "validates expired token and caches result" do
      token = "at_expired_token_456"
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client")

      token_data = %{
        token: token,
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
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token:introspect:#{token}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == false
      assert result.active == false
      assert result.expired == true

      Process.sleep(50)
    end
  end

  describe "execute/2 - cache unavailable" do
    test "falls back to database when cache service is unavailable" do
      token = "at_fallback_token_123"
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_789")

      token_data = %{
        token: token,
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
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token:introspect:#{token}"

      # Cache service unavailable
      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :cache_unavailable}
      end)

      # Fallback to database
      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      # Should NOT attempt to cache when cache is unavailable

      assert {:ok, result} = CachedValidateToken.execute(token, deps)

      assert result.valid == true
      assert result.active == true
      assert result.scope == ["openid"]
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
      assert {:error, :invalid_token_format} = CachedValidateToken.execute(%{}, deps)
    end
  end

  describe "execute_with_scope/3 - cache hit" do
    test "returns cached scope validation result when available" do
      token = "at_scoped_token_123"
      required_scope = "openid profile"
      {:ok, user_id} = UserId.generate()

      cached_result = %{
        valid: true,
        active: true,
        has_required_scope: true,
        scope: ["openid", "profile", "email"],
        client_id: "test_client_123",
        user_id: to_string(user_id),
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

      # Generate expected scope hash
      scope_hash =
        :crypto.hash(:sha256, required_scope)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      cache_key = "token:scope:#{token}:#{scope_hash}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:ok, cached_result}
      end)

      assert {:ok, result} = CachedValidateToken.execute_with_scope(token, required_scope, deps)

      assert result == cached_result
      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == true
    end

    test "returns cached scope validation failure" do
      token = "at_limited_scope_123"
      required_scope = "admin"

      cached_result = %{
        valid: true,
        active: true,
        has_required_scope: false,
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

      scope_hash =
        :crypto.hash(:sha256, required_scope)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      cache_key = "token:scope:#{token}:#{scope_hash}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:ok, cached_result}
      end)

      assert {:ok, result} = CachedValidateToken.execute_with_scope(token, required_scope, deps)

      assert result.has_required_scope == false
    end
  end

  describe "execute_with_scope/3 - cache miss" do
    test "validates scope and caches result on cache miss" do
      token = "at_scope_miss_123"
      required_scope = "openid profile"
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client_123")

      token_data = %{
        token: token,
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
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      scope_hash =
        :crypto.hash(:sha256, required_scope)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      cache_key = "token:scope:#{token}:#{scope_hash}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      assert {:ok, result} = CachedValidateToken.execute_with_scope(token, required_scope, deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == true

      Process.sleep(50)
    end

    test "validates scope for token missing required scope" do
      token = "at_insufficient_scope_123"
      required_scope = "openid profile email"
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client")

      token_data = %{
        token: token,
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
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      scope_hash =
        :crypto.hash(:sha256, required_scope)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      cache_key = "token:scope:#{token}:#{scope_hash}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      assert {:ok, result} = CachedValidateToken.execute_with_scope(token, required_scope, deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == false

      Process.sleep(50)
    end

    test "returns invalid result for token not found with scope check" do
      token = "at_not_found_123"
      required_scope = "openid"

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      scope_hash =
        :crypto.hash(:sha256, required_scope)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      cache_key = "token:scope:#{token}:#{scope_hash}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:error, :not_found}
      end)

      assert {:ok, result} = CachedValidateToken.execute_with_scope(token, required_scope, deps)

      assert result.valid == false
      assert result.active == false
      assert result.has_required_scope == false

      Process.sleep(50)
    end
  end

  describe "execute_with_scope/3 - cache unavailable" do
    test "falls back to database when cache is unavailable for scope validation" do
      token = "at_scope_fallback_123"
      required_scope = "openid"
      {:ok, user_id} = UserId.generate()
      {:ok, client_id} = ClientId.new("test_client")

      token_data = %{
        token: token,
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
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      scope_hash =
        :crypto.hash(:sha256, required_scope)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      cache_key = "token:scope:#{token}:#{scope_hash}"

      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :cache_unavailable}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:ok, token_data}
      end)

      assert {:ok, result} = CachedValidateToken.execute_with_scope(token, required_scope, deps)

      assert result.valid == true
      assert result.active == true
      assert result.has_required_scope == true
    end
  end

  describe "invalidate/2" do
    test "invalidates cache for token" do
      token = "at_to_invalidate_123"

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token:introspect:#{token}"

      expect(MockCacheService, :delete, fn ^cache_key ->
        :ok
      end)

      assert :ok = CachedValidateToken.invalidate(token, deps)
    end

    test "returns error when cache delete fails" do
      token = "at_delete_fails_123"

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      cache_key = "token:introspect:#{token}"

      expect(MockCacheService, :delete, fn ^cache_key ->
        {:error, :cache_unavailable}
      end)

      assert {:error, :cache_unavailable} = CachedValidateToken.invalidate(token, deps)
    end

    test "returns error for non-binary token" do
      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      assert {:error, :invalid_token_format} = CachedValidateToken.invalidate(123, deps)
      assert {:error, :invalid_token_format} = CachedValidateToken.invalidate(nil, deps)
      assert {:error, :invalid_token_format} = CachedValidateToken.invalidate(:atom, deps)
    end
  end

  describe "cache key generation" do
    test "generates consistent cache keys for token validation" do
      token = "at_test_token_123"

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      expected_key = "token:introspect:#{token}"

      expect(MockCacheService, :get, fn ^expected_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:error, :not_found}
      end)

      CachedValidateToken.execute(token, deps)

      Process.sleep(50)
    end

    test "generates different scope cache keys for different scopes" do
      token = "at_scope_test_123"
      scope1 = "openid profile"
      scope2 = "openid email"

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      hash1 =
        :crypto.hash(:sha256, scope1)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      hash2 =
        :crypto.hash(:sha256, scope2)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      # Hashes should be different
      assert hash1 != hash2

      key1 = "token:scope:#{token}:#{hash1}"
      key2 = "token:scope:#{token}:#{hash2}"

      expect(MockCacheService, :get, 2, fn key ->
        assert key in [key1, key2]
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, 2, fn ^token ->
        {:error, :not_found}
      end)

      CachedValidateToken.execute_with_scope(token, scope1, deps)
      CachedValidateToken.execute_with_scope(token, scope2, deps)

      Process.sleep(50)
    end

    test "generates same scope cache key for same scope" do
      token = "at_same_scope_123"
      scope = "openid profile"

      deps = %{
        token_repository: MockTokenRepository,
        cache_service: MockCacheService
      }

      hash =
        :crypto.hash(:sha256, scope)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      cache_key = "token:scope:#{token}:#{hash}"

      # First call - cache miss
      expect(MockCacheService, :get, fn ^cache_key ->
        {:error, :not_found}
      end)

      expect(MockTokenRepository, :find, fn ^token ->
        {:error, :not_found}
      end)

      CachedValidateToken.execute_with_scope(token, scope, deps)

      Process.sleep(50)

      # Second call - would use same cache key if cache worked
      cached_result = %{
        valid: false,
        active: false,
        has_required_scope: false,
        scope: [],
        client_id: nil,
        user_id: nil,
        organization_id: nil,
        email: nil,
        exp: nil,
        iat: nil,
        revoked: nil,
        expired: nil,
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

      expect(MockCacheService, :get, fn ^cache_key ->
        {:ok, cached_result}
      end)

      assert {:ok, _result} = CachedValidateToken.execute_with_scope(token, scope, deps)
    end
  end
end
