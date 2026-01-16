defmodule Thalamus.Application.UseCases.ValidateTokenTest do
  use ExUnit.Case, async: true

  import Mox

  alias Thalamus.Application.UseCases.ValidateToken
  alias Thalamus.Domain.ValueObjects.{UserId, ClientId}

  # Define mock
  defmodule MockTokenRepository do
    @behaviour Thalamus.Application.Ports.TokenRepository

    def store(_token_data), do: :ok
    def find(_token), do: {:error, :not_found}
    def revoke(_token), do: :ok
    def revoke_all_for_user(_user_id), do: :ok
    def revoke_all_for_client(_client_id), do: :ok
    def cleanup_expired(), do: {:ok, 0}
    def find_by_user(_user_id), do: {:ok, []}
  end

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
end
