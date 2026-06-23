defmodule Thalamus.Application.UseCases.GenerateTokensTest do
  use ExUnit.Case, async: false

  import Mox

  alias Thalamus.Application.UseCases.GenerateTokens
  alias Thalamus.Application.DTOs.{TokenRequest, TokenResponse}
  alias Thalamus.Domain.Entities.{User, OAuth2Client}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, ClientId, GrantType, PasswordHash}

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
      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :store, 1, fn token_data ->
        assert token_data.type == :access_token
        assert String.starts_with?(token_data.token, "eyJ")
        assert token_data.scopes == ["api:read"]
        assert is_nil(token_data.user_id)
        :ok
      end)

      expect(MockAuditLogger, :log_client_event, fn _client_id, :token_generated, _context ->
        :ok
      end)

      # Execute
      {:ok, response} = GenerateTokens.execute(request, deps)

      # Assert
      assert %TokenResponse{} = response
      assert String.starts_with?(response.access_token, "eyJ")
      assert response.token_type == "Bearer"
      assert response.expires_in == 604_800
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

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
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

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
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

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
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

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
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
        name: "Test User",
        password_hash: nil,
        status: :active,
        is_agent: true,
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

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      # Mock finding authorization code
      expect(MockTokenRepository, :find, fn "auth_code_123" ->
        {:ok,
         %{
           type: :authorization_code,
           user_id: user_id,
           client_id: client_id,
           scopes: ["openid", "profile"],
           expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
           revoked: false
         }}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, user}
      end)

      expect(MockTokenRepository, :store, 2, fn _token_data ->
        :ok
      end)

      expect(MockTokenRepository, :revoke, 1, fn "auth_code_123" ->
        :ok
      end)

      expect(MockAuditLogger, :log_token_generated, fn ^user_id, _client_id, _context ->
        :ok
      end)

      {:ok, response} = GenerateTokens.execute(request, deps)

      assert %TokenResponse{} = response
      assert String.starts_with?(response.access_token, "eyJ")
      assert String.starts_with?(response.refresh_token, "rt_")
      assert response.token_type == "Bearer"
      assert response.expires_in == 3600

      # Verify JWT claims contain user info
      jwt_claims = decode_jwt_payload(response.access_token)
      assert jwt_claims["sub"] == Thalamus.Domain.ValueObjects.UserId.to_string(user_id)
      assert jwt_claims["name"] == "Test User"
      assert jwt_claims["email"] == "user@example.com"
      assert jwt_claims["is_agent"] == true
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

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
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

      {:ok, email} = Email.new("refresh_user@example.com")

      refresh_user = %User{
        id: user_id,
        email: email,
        name: "Refresh User",
        password_hash: nil,
        status: :active,
        is_agent: false,
        failed_login_attempts: 0,
        mfa_methods: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
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

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :find, fn "rt_old_token" ->
        {:ok, stored_token}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:ok, refresh_user}
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
      assert String.starts_with?(response.access_token, "eyJ")
      assert String.starts_with?(response.refresh_token, "rt_")
      assert response.refresh_token != "rt_old_token"

      # Verify JWT claims contain user info
      jwt_claims = decode_jwt_payload(response.access_token)
      assert jwt_claims["sub"] == Thalamus.Domain.ValueObjects.UserId.to_string(user_id)
      assert jwt_claims["name"] == "Refresh User"
      assert jwt_claims["email"] == "refresh_user@example.com"
      assert jwt_claims["is_agent"] == false
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

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :find, fn "rt_old_token" ->
        {:ok, stored_token}
      end)

      {:error, :token_client_mismatch} = GenerateTokens.execute(request, deps)
    end
  end

  describe "execute/2 - password grant (deprecated)" do
    test "generates token for password grant type" do
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

      {:ok, user_id} = UserId.new("user_123")
      {:ok, email_vo} = Email.new("user@example.com")
      {:ok, pwd_hash} = PasswordHash.from_password("Password123!")

      user = %User{
        id: user_id,
        email: email_vo,
        name: "Test User",
        password_hash: pwd_hash,
        status: :active,
        is_agent: false,
        organization_id: "org_123"
      }

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "password",
          client_id: "test_client_123",
          client_secret: client_secret,
          username: "user@example.com",
          password: "Password123!"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockUserRepository, :find_by_email, fn _ ->
        {:ok, user}
      end)

      stub(MockAuditLogger, :log, fn _ -> :ok end)
      stub(MockAuditLogger, :log_token_generated, fn _, _, _ -> :ok end)
      stub(MockTokenRepository, :store, fn _ -> :ok end)

      {:ok, response} = GenerateTokens.execute(request, deps)
      assert response.token_type == "Bearer"
      assert Map.has_key?(response, :access_token)
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

      # Create request manually to bypass DTO validation that requires client_secret
      # Public clients don't need client_secret
      request = %TokenRequest{
        grant_type: :client_credentials,
        client_id: "test_client_123",
        client_secret: nil,
        scope: "api:read"
      }

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
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
      assert String.starts_with?(response.access_token, "eyJ")
    end
  end

  describe "execute/2 - error handling" do
    test "returns error when client not found" do
      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "client_credentials",
          client_id: "nonexistent_client",
          client_secret: "secret",
          scope: "api:read"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "nonexistent_client" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = GenerateTokens.execute(request, deps)
    end

    test "returns error when authorization code not found" do
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
          code: "invalid_code",
          redirect_uri: "https://example.com/callback"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :find, fn "invalid_code" ->
        {:error, :not_found}
      end)

      assert {:error, :invalid_grant} = GenerateTokens.execute(request, deps)
    end

    test "returns error when authorization code has wrong type" do
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
          code: "wrong_type_token",
          redirect_uri: "https://example.com/callback"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :find, fn "wrong_type_token" ->
        {:ok,
         %{
           type: :access_token,
           # Wrong type - should be :authorization_code
           expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
         }}
      end)

      assert {:error, :invalid_grant} = GenerateTokens.execute(request, deps)
    end

    test "returns error when authorization code is expired" do
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
          code: "expired_code",
          redirect_uri: "https://example.com/callback"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :find, fn "expired_code" ->
        {:ok,
         %{
           type: :authorization_code,
           expires_at: DateTime.add(DateTime.utc_now(), -600, :second)
         }}
      end)

      assert {:error, :expired_authorization_code} = GenerateTokens.execute(request, deps)
    end

    test "returns error when refresh token not found" do
      {:ok, client_id} = ClientId.new("test_client_123")
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

      {:ok, request} =
        TokenRequest.new(%{
          grant_type: "refresh_token",
          client_id: "test_client_123",
          client_secret: client_secret,
          refresh_token: "invalid_token"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :find, fn "invalid_token" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = GenerateTokens.execute(request, deps)
    end

    test "returns error when user not found for authorization code" do
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
          code: "valid_code",
          redirect_uri: "https://example.com/callback"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :find, fn "valid_code" ->
        {:ok,
         %{
           type: :authorization_code,
           user_id: user_id,
           client_id: client_id,
           scopes: ["openid"],
           expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
           revoked: false
         }}
      end)

      expect(MockUserRepository, :find_by_id, fn ^user_id ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = GenerateTokens.execute(request, deps)
    end
  end

  describe "execute/2 - scope handling" do
    test "generates tokens with nil scope (empty scopes)" do
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
          client_secret: client_secret
          # No scope provided - will be nil
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :store, 1, fn token_data ->
        assert token_data.scopes == []
        :ok
      end)

      expect(MockAuditLogger, :log_client_event, fn _client_id, :token_generated, _context ->
        :ok
      end)

      {:ok, response} = GenerateTokens.execute(request, deps)

      assert %TokenResponse{} = response
      assert response.scope == ""
    end

    test "generates tokens with empty string scope" do
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
          scope: ""
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :store, 1, fn token_data ->
        assert token_data.scopes == []
        :ok
      end)

      expect(MockAuditLogger, :log_client_event, fn _client_id, :token_generated, _context ->
        :ok
      end)

      {:ok, response} = GenerateTokens.execute(request, deps)

      assert %TokenResponse{} = response
      assert response.scope == ""
    end

    test "generates tokens with multiple scopes" do
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
        allowed_scopes: ["api:read", "api:write", "api:admin"],
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
          scope: "api:read api:write"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      expect(MockTokenRepository, :store, 1, fn token_data ->
        assert token_data.scopes == ["api:read", "api:write"]
        :ok
      end)

      expect(MockAuditLogger, :log_client_event, fn _client_id, :token_generated, _context ->
        :ok
      end)

      {:ok, response} = GenerateTokens.execute(request, deps)

      assert %TokenResponse{} = response
      assert response.scope == "api:read api:write"
    end
  end

  describe "execute/2 - edge cases and full coverage" do
    test "handles client_id as struct (ClientId value object) in store_tokens" do
      # This test ensures the store_tokens path that handles ClientId structs is covered
      {:ok, client_id} = ClientId.new("test_client_123")
      {:ok, grant_type} = GrantType.new(:client_credentials)

      client_secret =
        "secret_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      client = %OAuth2Client{
        id: client_id,
        # ClientId struct, not string
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
          scope: "api:read"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      # Verify the client_id struct is handled correctly
      expect(MockTokenRepository, :store, 1, fn token_data ->
        # Should extract the value and remove "client_" prefix
        assert is_binary(token_data.client_id)
        :ok
      end)

      expect(MockAuditLogger, :log_client_event, fn _client_id, :token_generated, _context ->
        :ok
      end)

      {:ok, response} = GenerateTokens.execute(request, deps)

      assert %TokenResponse{} = response
    end

    test "returns error from verify_authorization_code with generic error" do
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
          code: "error_code",
          redirect_uri: "https://example.com/callback"
        })

      deps = %{
        oauth2_client_repository: MockOAuth2ClientRepository,
        user_repository: MockUserRepository,
        token_repository: MockTokenRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockOAuth2ClientRepository, :find_by_client_id, fn "test_client_123" ->
        {:ok, client}
      end)

      # Return a generic error (not :not_found)
      expect(MockTokenRepository, :find, fn "error_code" ->
        {:error, :database_error}
      end)

      assert {:error, :database_error} = GenerateTokens.execute(request, deps)
    end
  end

  # --- Helpers ---

  defp decode_jwt_payload(token) do
    [_header, payload, _signature] = String.split(token, ".")
    {:ok, decoded} = Base.url_decode64(payload, padding: false)
    Jason.decode!(decoded)
  end
end
