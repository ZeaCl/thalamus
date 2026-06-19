defmodule Thalamus.Application.UseCases.GenerateTokensTest do
  use ExUnit.Case, async: true

  import Mox

  alias Thalamus.Application.UseCases.GenerateTokens
  alias Thalamus.Application.DTOs.{TokenRequest, TokenResponse}
  alias Thalamus.Domain.Entities.{User, OAuth2Client}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, ClientId, GrantType}

  setup :verify_on_exit!

  describe "execute/2 - client_credentials grant" do
    test "generates tokens for valid client credentials" do
      # Setup test client
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, grant_type} = GrantType.new(:client_credentials)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [grant_type],
        allowed_scopes: ["api:read", "api:write"],
        redirect_uris: [],
        is_active: true,
        trusted: false,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      # Create request
      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "client_credentials",
          client_id: "test_client_123",
          client_secret: client_secret,
          scope: "api:read"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      # Mock expectations
      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :store, 1, fn token_data ->
        assert token_data.type == :access_token
        assert String.starts_with?(token_data.token, "at_")
        assert token_data.client_id == client_id
        assert token_data.scopes == ["api:read"]
        assert is_nil(token_data.user_id)
        :ok
      end)

      expect(MockAuditLogger, :log_client_event, fn ^client_id, :token_generated, _context ->
        :ok
      end)

      # Execute
      {:ok, response} = GenerateTokens.execute(request, deps)

      # Assert
      assert %TokenResponse{} = response
      assert String.starts_with?(response.access_token, "at_")
      assert response.token_type == "Bearer"
      assert response.expires_in == 3600
      assert is_nil(response.refresh_token)
      assert response.scope == "api:read"
    end

    test "returns error for invalid scope" do
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, grant_type} = GrantType.new(:client_credentials)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [grant_type],
        allowed_scopes: ["api:read"],
        redirect_uris: [],
        is_active: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "client_credentials",
          client_id: "test_client_123",
          client_secret: client_secret,
          scope: "api:admin"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      {:error, :invalid_scope} = GenerateTokens.execute(request, deps)
    end

    test "returns error for inactive client" do
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, grant_type} = GrantType.new(:client_credentials)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [grant_type],
        allowed_scopes: ["api:read"],
        redirect_uris: [],
        is_active: false,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "client_credentials",
          client_id: "test_client_123",
          client_secret: client_secret,
          scope: "api:read"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      {:error, :client_inactive} = GenerateTokens.execute(request, deps)
    end

    test "returns error for invalid client secret" do
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, grant_type} = GrantType.new(:client_credentials)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [grant_type],
        allowed_scopes: ["api:read"],
        redirect_uris: [],
        is_active: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "client_credentials",
          client_id: "test_client_123",
          client_secret: "wrong_secret",
          scope: "api:read"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      {:error, :invalid_client_secret} = GenerateTokens.execute(request, deps)
    end

    test "returns error for unsupported grant type" do
      {:ok, client_id} = ClientId.new("test_client_123")

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [],
        allowed_scopes: ["api:read"],
        redirect_uris: [],
        is_active: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "client_credentials",
          client_id: "test_client_123",
          client_secret: client_secret,
          scope: "api:read"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      {:error, :unsupported_grant_type} = GenerateTokens.execute(request, deps)
    end
  end

  describe "execute/2 - authorization_code grant" do
    test "generates tokens for valid authorization code" do
      # Setup test client and user
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, user_id} = UserId.generate()
      {:ok, grant_type} = GrantType.new(:authorization_code)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [grant_type],
        allowed_scopes: ["openid", "profile"],
        redirect_uris: ["https://example.com/callback"],
        is_active: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, email} = Email.new("user@example.com")

      user = %User{
        id: user_id,
        email: email,
        password_hash: nil,
        status: :active,
        failed_login_attempts: 0,
        mfa_methods: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "authorization_code",
          client_id: "test_client_123",
          client_secret: client_secret,
          code: "auth_code_123",
          redirect_uri: "https://example.com/callback"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_id, fn nil ->
        {:ok, user}
      end)

      expect(MockTokenRepository, :store, 2, fn token_data ->
        assert token_data.client_id == client_id
        :ok
      end)

      expect(MockAuditLogger, :log_token_generated, fn _user_id, ^client_id, _context ->
        :ok
      end)

      {:ok, response} = GenerateTokens.execute(request, deps)

      assert %TokenResponse{} = response
      assert String.starts_with?(response.access_token, "at_")
      assert String.starts_with?(response.refresh_token, "rt_")
      assert response.token_type == "Bearer"
      assert response.expires_in == 3600
    end

    test "returns error for invalid redirect_uri" do
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, grant_type} = GrantType.new(:authorization_code)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [grant_type],
        allowed_scopes: ["openid"],
        redirect_uris: ["https://example.com/callback"],
        is_active: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "authorization_code",
          client_id: "test_client_123",
          client_secret: client_secret,
          code: "auth_code_123",
          redirect_uri: "https://evil.com/callback"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      {:error, :invalid_redirect_uri} = GenerateTokens.execute(request, deps)
    end
  end

  describe "execute/2 - refresh_token grant" do
    test "generates new tokens from valid refresh token" do
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, user_id} = UserId.generate()
      {:ok, grant_type} = GrantType.new(:refresh_token)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [grant_type],
        allowed_scopes: ["openid", "profile"],
        redirect_uris: [],
        is_active: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      stored_token = %{
        token: "rt_old_token",
        type: :refresh_token,
        user_id: user_id,
        client_id: client_id,
        scopes: ["openid", "profile"],
        scope: "openid profile",
        expires_at: DateTime.add(DateTime.utc_now(), 86400, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "refresh_token",
          client_id: "test_client_123",
          client_secret: client_secret,
          refresh_token: "rt_old_token"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :find, fn "rt_old_token" ->
        {:ok, stored_token}
      end)

      expect(MockTokenRepository, :revoke, fn "rt_old_token" ->
        :ok
      end)

      expect(MockTokenRepository, :store, 2, fn _token_data ->
        :ok
      end)

      expect(MockAuditLogger, :log_token_generated, fn ^user_id, ^client_id, _context ->
        :ok
      end)

      {:ok, response} = GenerateTokens.execute(request, deps)

      assert %TokenResponse{} = response
      assert String.starts_with?(response.access_token, "at_")
      assert String.starts_with?(response.refresh_token, "rt_")
      assert response.refresh_token != "rt_old_token"
    end

    test "returns error for token/client mismatch" do
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, other_client_id} = ClientId.new("other_client_456")
      {:ok, user_id} = UserId.generate()
      {:ok, grant_type} = GrantType.new(:refresh_token)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [grant_type],
        allowed_scopes: ["openid"],
        redirect_uris: [],
        is_active: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      stored_token = %{
        token: "rt_old_token",
        type: :refresh_token,
        user_id: user_id,
        client_id: other_client_id,
        scopes: ["openid"],
        scope: "openid",
        expires_at: DateTime.add(DateTime.utc_now(), 86400, :second),
        revoked: false,
        created_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "refresh_token",
          client_id: "test_client_123",
          client_secret: client_secret,
          refresh_token: "rt_old_token"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :find, fn "rt_old_token" ->
        {:ok, stored_token}
      end)

      {:error, :token_client_mismatch} = GenerateTokens.execute(request, deps)
    end
  end

  describe "execute/2 - password grant (deprecated)" do
    test "returns error for password grant type" do
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, grant_type} = GrantType.new(:password)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: client_secret,
        grant_types: [grant_type],
        allowed_scopes: ["openid"],
        redirect_uris: [],
        is_active: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "password",
          client_id: "test_client_123",
          client_secret: client_secret,
          username: "user@example.com",
          password: "password123"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      {:error, :deprecated_grant_type} = GenerateTokens.execute(request, deps)
    end
  end

  describe "execute/2 - public clients" do
    test "generates tokens for public client without secret" do
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, grant_type} = GrantType.new(:client_credentials)

      client = %OAuth2Client{
        id: client_id,
        name: "Test Public Client",
        client_type: :public,
        client_secret: nil,
        grant_types: [grant_type],
        allowed_scopes: ["api:read"],
        redirect_uris: [],
        is_active: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "client_credentials",
          client_id: "test_client_123",
          scope: "api:read"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_id, fn ^client_id ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :store, fn _token_data ->
        :ok
      end)

      expect(MockAuditLogger, :log_client_event, fn ^client_id, :token_generated, _context ->
        :ok
      end)

      {:ok, response} = GenerateTokens.execute(request, deps)

      assert %TokenResponse{} = response
      assert String.starts_with?(response.access_token, "at_")
    end
  end
end
