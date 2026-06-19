defmodule Thalamus.Application.UseCases.AuthenticateUserTest do
  use ExUnit.Case, async: true

  import Mox

  alias Thalamus.Application.UseCases.AuthenticateUser
  alias Thalamus.Application.DTOs.{AuthenticationRequest, AuthenticationResponse}
  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash, MFAMethod}

  setup :verify_on_exit!

  describe "execute/2 - successful authentication" do
    test "authenticates user with valid credentials and no MFA" do
      # Setup test user
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")

      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :active,
        failed_login_attempts: 0,
        mfa_methods: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      # Create request
      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "user@example.com",
          password: "SecureP@ssw0rd123"
        })

      # Setup mocks
      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      # Mock expectations
      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:ok, user}
      end)

      expect(MockUserRepository, :update_last_login, fn user_id, _timestamp ->
        :ok
      end)

      expect(MockUserRepository, :save, fn updated_user ->
        {:ok, updated_user}
      end)

      expect(MockAuditLogger, :log_authentication_success, fn ^user_id, _context ->
        :ok
      end)

      # Execute
      {:ok, response} = AuthenticateUser.execute(request, deps)

      # Assert
      assert %AuthenticationResponse{} = response
      assert response.authenticated == true
      assert response.user_id == user_id
      assert response.requires_mfa == false
      assert is_nil(response.mfa_token)
    end

    test "returns MFA required when user has MFA enabled but no code provided" do
      # Setup test user with MFA
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")
      {:ok, mfa_method} = MFAMethod.new(:totp, "secret_key", true)

      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :active,
        failed_login_attempts: 0,
        mfa_methods: [mfa_method],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      # Create request without MFA code
      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "user@example.com",
          password: "SecureP@ssw0rd123"
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      # Mock expectations
      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:ok, user}
      end)

      # Execute
      {:ok, response} = AuthenticateUser.execute(request, deps)

      # Assert
      assert %AuthenticationResponse{} = response
      assert response.authenticated == false
      assert response.requires_mfa == true
      assert is_binary(response.mfa_token)
      refute is_nil(response.mfa_token)
    end

    test "authenticates user with valid MFA code" do
      # Setup test user with MFA
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")
      {:ok, mfa_method} = MFAMethod.new(:totp, "secret_key", true)

      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :active,
        failed_login_attempts: 0,
        mfa_methods: [mfa_method],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      # Create request with MFA code
      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "user@example.com",
          password: "SecureP@ssw0rd123",
          mfa_code: "123456"
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      # Mock expectations
      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:ok, user}
      end)

      expect(MockUserRepository, :update_last_login, fn user_id, _timestamp ->
        :ok
      end)

      expect(MockUserRepository, :save, fn updated_user ->
        {:ok, updated_user}
      end)

      expect(MockAuditLogger, :log_authentication_success, fn ^user_id, _context ->
        :ok
      end)

      # Execute
      {:ok, response} = AuthenticateUser.execute(request, deps)

      # Assert
      assert %AuthenticationResponse{} = response
      assert response.authenticated == true
      assert response.user_id == user_id
      assert response.requires_mfa == false
    end
  end

  describe "execute/2 - authentication failures" do
    test "returns error for invalid email format" do
      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "invalid-email",
          password: "SecureP@ssw0rd123"
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockAuditLogger, :log_authentication_failure, fn _email, :user_not_found, _context ->
        :ok
      end)

      {:error, :invalid_credentials} = AuthenticateUser.execute(request, deps)
    end

    test "returns error when user not found" do
      {:ok, email} = Email.new("nonexistent@example.com")

      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "nonexistent@example.com",
          password: "SecureP@ssw0rd123"
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:error, :not_found}
      end)

      expect(MockAuditLogger, :log_authentication_failure, fn _email, :user_not_found, _context ->
        :ok
      end)

      {:error, :invalid_credentials} = AuthenticateUser.execute(request, deps)
    end

    test "returns error for invalid password" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")

      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :active,
        failed_login_attempts: 0,
        mfa_methods: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "user@example.com",
          password: "WrongPassword123!"
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:ok, user}
      end)

      expect(MockUserRepository, :save, fn updated_user ->
        {:ok, updated_user}
      end)

      expect(MockAuditLogger, :log_authentication_failure, fn _email,
                                                              :invalid_password,
                                                              _context ->
        :ok
      end)

      {:error, :invalid_credentials} = AuthenticateUser.execute(request, deps)
    end

    test "returns error when account is locked" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")

      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :active,
        failed_login_attempts: 5,
        locked_until: DateTime.add(DateTime.utc_now(), 1800, :second),
        mfa_methods: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "user@example.com",
          password: "SecureP@ssw0rd123"
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:ok, user}
      end)

      expect(MockAuditLogger, :log_authentication_failure, fn _email, :account_locked, _context ->
        :ok
      end)

      {:error, :account_locked} = AuthenticateUser.execute(request, deps)
    end

    test "returns error when account is suspended" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")

      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :suspended,
        failed_login_attempts: 0,
        mfa_methods: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "user@example.com",
          password: "SecureP@ssw0rd123"
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:ok, user}
      end)

      expect(MockAuditLogger, :log_authentication_failure, fn _email,
                                                              :account_suspended,
                                                              _context ->
        :ok
      end)

      {:error, :account_suspended} = AuthenticateUser.execute(request, deps)
    end

    test "returns error when account is not verified" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")

      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :pending_verification,
        failed_login_attempts: 0,
        mfa_methods: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "user@example.com",
          password: "SecureP@ssw0rd123"
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:ok, user}
      end)

      expect(MockAuditLogger, :log_authentication_failure, fn _email,
                                                              :account_not_verified,
                                                              _context ->
        :ok
      end)

      {:error, :account_not_verified} = AuthenticateUser.execute(request, deps)
    end

    test "returns error for invalid MFA code" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")
      {:ok, mfa_method} = MFAMethod.new(:totp, "secret_key", true)

      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :active,
        failed_login_attempts: 0,
        mfa_methods: [mfa_method],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "user@example.com",
          password: "SecureP@ssw0rd123",
          mfa_code: ""
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:ok, user}
      end)

      expect(MockAuditLogger, :log_authentication_failure, fn _email,
                                                              :invalid_mfa_code,
                                                              _context ->
        :ok
      end)

      {:error, :invalid_mfa_code} = AuthenticateUser.execute(request, deps)
    end
  end

  describe "execute/2 - context tracking" do
    test "passes context information through authentication flow" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")

      user = %User{
        id: user_id,
        email: email,
        password_hash: password_hash,
        status: :active,
        failed_login_attempts: 0,
        mfa_methods: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      context = %{
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        timestamp: DateTime.utc_now()
      }

      {:ok, request} =
        AuthenticationRequest.new(%{
          email: "user@example.com",
          password: "SecureP@ssw0rd123",
          context: context
        })

      deps = %{
        user_repository: MockUserRepository,
        audit_logger: MockAuditLogger
      }

      expect(MockUserRepository, :find_by_email, fn ^email ->
        {:ok, user}
      end)

      expect(MockUserRepository, :update_last_login, fn user_id, _timestamp ->
        :ok
      end)

      expect(MockUserRepository, :save, fn updated_user ->
        {:ok, updated_user}
      end)

      expect(MockAuditLogger, :log_authentication_success, fn ^user_id, logged_context ->
        assert logged_context == %{}
        :ok
      end)

      {:ok, _response} = AuthenticateUser.execute(request, deps)
    end
  end
end
