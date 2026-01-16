defmodule ThalamusWeb.API.MFAController do
  @moduledoc """
  Controller for Multi-Factor Authentication (MFA) management.

  Provides endpoints for:
  - Setting up TOTP (Time-based One-Time Password)
  - Verifying TOTP codes
  - Disabling MFA
  - Managing backup codes

  All endpoints require authentication via Bearer token.
  """

  use ThalamusWeb, :controller

  alias Thalamus.Domain.ValueObjects.{UserId, MFAMethod}
  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository
  alias Thalamus.Infrastructure.Adapters.AuditLoggerImpl

  require Logger

  # ============================================================================
  # TOTP SETUP
  # ============================================================================

  @doc """
  POST /api/mfa/totp/setup

  Initiates TOTP setup for the authenticated user.
  Returns a secret and QR code data for scanning with authenticator apps.

  ## Request
  No body required - uses authenticated user from token

  ## Response
  - 200: TOTP setup data (secret, QR code URI, backup codes)
  - 400: MFA already enabled
  - 401: Unauthorized
  """
  def setup_totp(conn, _params) do
    user_id = conn.assigns[:current_user_id]

    with {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         :ok <- validate_mfa_not_enabled(user),
         {:ok, secret} <- generate_totp_secret(),
         {:ok, backup_codes} <- generate_backup_codes() do
      # Generate QR code URI for authenticator apps
      qr_uri = generate_totp_uri(user.email, secret)

      # Store pending MFA setup (not enabled until verified)
      store_pending_mfa_setup(user_id, secret, backup_codes)

      AuditLoggerImpl.log_mfa_setup_initiated(user_id)

      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          secret: secret,
          qr_code_uri: qr_uri,
          backup_codes: backup_codes,
          instructions: "Scan the QR code with your authenticator app, then verify with a code."
        }
      })
    else
      {:error, :mfa_already_enabled} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "MFA is already enabled for this account"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, reason} ->
        Logger.error("TOTP setup failed: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to setup TOTP"})
    end
  end

  @doc """
  POST /api/mfa/totp/verify

  Verifies TOTP code and enables MFA for the user.

  ## Request Body
  ```json
  {
    "code": "123456"
  }
  ```

  ## Response
  - 200: MFA enabled successfully
  - 400: Invalid code or no pending setup
  - 401: Unauthorized
  """
  def verify_totp(conn, %{"code" => code}) do
    user_id = conn.assigns[:current_user_id]

    with {:ok, pending_setup} <- get_pending_mfa_setup(user_id),
         :ok <- validate_totp_code(code, pending_setup.secret),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         {:ok, mfa_method} <- MFAMethod.new(:totp, pending_setup.secret),
         {:ok, _updated_user} <- enable_mfa_for_user(user, mfa_method) do
      # Clear pending setup
      clear_pending_mfa_setup(user_id)

      AuditLoggerImpl.log_mfa_enabled(user_id, :totp, %{})

      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          mfa_enabled: true,
          method: "totp",
          backup_codes: pending_setup.backup_codes,
          message: "MFA has been successfully enabled. Save your backup codes in a safe place."
        }
      })
    else
      {:error, :no_pending_setup} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "No pending MFA setup found. Please initiate setup first."})

      {:error, :invalid_code} ->
        AuditLoggerImpl.log_mfa_verification_failed(user_id, :totp)

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid verification code"})

      {:error, reason} ->
        Logger.error("TOTP verification failed: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to verify TOTP"})
    end
  end

  def verify_totp(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required field: code"})
  end

  # ============================================================================
  # MFA VERIFICATION (For Login)
  # ============================================================================

  @doc """
  POST /api/mfa/verify

  Verifies MFA code during login flow.
  Used by authentication system to complete 2FA login.

  ## Request Body
  ```json
  {
    "user_id": "uuid",
    "code": "123456"
  }
  ```

  ## Response
  - 200: Code verified
  - 400: Invalid code
  - 401: Unauthorized
  """
  def verify_mfa_code(conn, %{"user_id" => user_id_string, "code" => code}) do
    with {:ok, user_id} <- UserId.new(user_id_string),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         :ok <- validate_user_has_mfa(user),
         {:ok, mfa_method} <- get_user_totp_method(user),
         :ok <- validate_totp_code(code, mfa_method.secret) do
      AuditLoggerImpl.log_mfa_verification_success(user_id, :totp)

      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          verified: true
        }
      })
    else
      {:error, :mfa_not_enabled} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "MFA is not enabled for this user"})

      {:error, :invalid_code} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid verification code"})

      {:error, reason} ->
        Logger.error("MFA verification failed: #{inspect(reason)}")

        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Verification failed"})
    end
  end

  def verify_mfa_code(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: user_id, code"})
  end

  # ============================================================================
  # MFA DISABLE
  # ============================================================================

  @doc """
  DELETE /api/mfa/disable

  Disables MFA for the authenticated user.
  Requires current password for security.

  ## Request Body
  ```json
  {
    "password": "current_password",
    "code": "123456"
  }
  ```

  ## Response
  - 200: MFA disabled
  - 400: Invalid credentials or code
  - 401: Unauthorized
  """
  def disable_mfa(conn, %{"password" => password, "code" => code}) do
    user_id = conn.assigns[:current_user_id]

    with {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         :ok <- validate_user_has_mfa(user),
         :ok <- validate_user_password(user, password),
         {:ok, mfa_method} <- get_user_totp_method(user),
         :ok <- validate_totp_code(code, mfa_method.secret),
         {:ok, _updated_user} <- disable_mfa_for_user(user) do
      AuditLoggerImpl.log_mfa_disabled(user_id)

      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          mfa_enabled: false,
          message: "MFA has been disabled for your account"
        }
      })
    else
      {:error, :mfa_not_enabled} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "MFA is not enabled for this account"})

      {:error, :invalid_password} ->
        AuditLoggerImpl.log_failed_login(user_id, "invalid_password_for_mfa_disable")

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid password"})

      {:error, :invalid_code} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid verification code"})

      {:error, reason} ->
        Logger.error("MFA disable failed: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to disable MFA"})
    end
  end

  def disable_mfa(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: password, code"})
  end

  # ============================================================================
  # BACKUP CODES
  # ============================================================================

  @doc """
  POST /api/mfa/backup-codes/regenerate

  Regenerates backup codes for the authenticated user.
  Requires current password and MFA code for security.

  ## Request Body
  ```json
  {
    "password": "current_password",
    "code": "123456"
  }
  ```

  ## Response
  - 200: New backup codes
  - 400: Invalid credentials
  - 401: Unauthorized
  """
  def regenerate_backup_codes(conn, %{"password" => password, "code" => code}) do
    user_id = conn.assigns[:current_user_id]

    with {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         :ok <- validate_user_has_mfa(user),
         :ok <- validate_user_password(user, password),
         {:ok, mfa_method} <- get_user_totp_method(user),
         :ok <- validate_totp_code(code, mfa_method.secret),
         {:ok, backup_codes} <- generate_backup_codes(),
         :ok <- store_backup_codes(user_id, backup_codes) do
      AuditLoggerImpl.log_backup_codes_regenerated(user_id)

      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          backup_codes: backup_codes,
          message: "New backup codes generated. Save them in a safe place."
        }
      })
    else
      {:error, reason} ->
        Logger.error("Backup codes regeneration failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to regenerate backup codes"})
    end
  end

  def regenerate_backup_codes(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: password, code"})
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp validate_mfa_not_enabled(user) do
    if user.mfa_enabled do
      {:error, :mfa_already_enabled}
    else
      :ok
    end
  end

  defp validate_user_has_mfa(user) do
    if user.mfa_enabled do
      :ok
    else
      {:error, :mfa_not_enabled}
    end
  end

  defp generate_totp_secret do
    # Generate 32-character base32 secret (160 bits)
    secret =
      :crypto.strong_rand_bytes(20)
      |> Base.encode32(padding: false)

    {:ok, secret}
  end

  defp generate_backup_codes do
    # Generate 10 backup codes (8 characters each)
    codes =
      for _ <- 1..10 do
        :crypto.strong_rand_bytes(4)
        |> Base.encode16(case: :lower)
      end

    {:ok, codes}
  end

  defp generate_totp_uri(email, secret) do
    email_string = to_string(email)
    issuer = "ZEA Thalamus"

    # otpauth://totp/ZEA%20Thalamus:user@example.com?secret=SECRET&issuer=ZEA%20Thalamus
    "otpauth://totp/#{URI.encode(issuer)}:#{URI.encode(email_string)}?secret=#{secret}&issuer=#{URI.encode(issuer)}"
  end

  defp store_pending_mfa_setup(user_id, secret, backup_codes) do
    # Store in Redis with 10 minute expiration
    cache_key = "mfa:pending:#{UserId.to_string(user_id)}"

    data = %{
      secret: secret,
      backup_codes: backup_codes,
      created_at: DateTime.utc_now() |> DateTime.to_unix()
    }

    case Thalamus.Infrastructure.Adapters.RedisCacheAdapter.set(
           cache_key,
           Jason.encode!(data),
           600
         ) do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end

  defp get_pending_mfa_setup(user_id) do
    cache_key = "mfa:pending:#{UserId.to_string(user_id)}"

    case Thalamus.Infrastructure.Adapters.RedisCacheAdapter.get(cache_key) do
      {:ok, json_data} ->
        data = Jason.decode!(json_data, keys: :atoms)
        {:ok, data}

      {:error, :not_found} ->
        {:error, :no_pending_setup}

      {:error, _} = error ->
        error
    end
  end

  defp clear_pending_mfa_setup(user_id) do
    cache_key = "mfa:pending:#{UserId.to_string(user_id)}"
    Thalamus.Infrastructure.Adapters.RedisCacheAdapter.delete(cache_key)
  end

  defp validate_totp_code(code, secret) when is_binary(code) and is_binary(secret) do
    # Validate code format (6 digits)
    unless String.match?(code, ~r/^\d{6}$/) do
      {:error, :invalid_code}
    end

    # Get current Unix time (30-second intervals)
    current_time = System.os_time(:second)
    time_step = 30

    # Check current window and +/- 1 window for clock skew
    valid_windows = [
      div(current_time, time_step) - 1,
      div(current_time, time_step),
      div(current_time, time_step) + 1
    ]

    valid =
      Enum.any?(valid_windows, fn window ->
        expected_code = generate_totp_code(secret, window)
        expected_code == code
      end)

    if valid do
      :ok
    else
      {:error, :invalid_code}
    end
  end

  defp validate_totp_code(_, _), do: {:error, :invalid_code}

  defp generate_totp_code(secret, time_window) do
    # Decode base32 secret
    decoded_secret = Base.decode32!(secret, padding: false)

    # Convert time window to 8-byte big-endian integer
    time_bytes = <<time_window::unsigned-big-integer-64>>

    # Generate HMAC-SHA1
    hmac = :crypto.mac(:hmac, :sha, decoded_secret, time_bytes)

    # Dynamic truncation (RFC 4226)
    <<_::binary-size(19), offset::4, _::4>> = hmac
    <<_::binary-size(offset), _::1, code::31, _::binary>> = hmac

    # Generate 6-digit code
    code
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp enable_mfa_for_user(user, mfa_method) do
    # Update user with MFA method
    updated_user = %Thalamus.Domain.Entities.User{user | mfa_methods: [mfa_method]}

    PostgreSQLUserRepository.save(updated_user)
  end

  defp disable_mfa_for_user(user) do
    updated_user = %Thalamus.Domain.Entities.User{user | mfa_methods: []}

    PostgreSQLUserRepository.save(updated_user)
  end

  defp get_user_totp_method(user) do
    totp_method =
      Enum.find(user.mfa_methods, fn method ->
        method.method_type == :totp
      end)

    if totp_method do
      {:ok, totp_method}
    else
      {:error, :totp_not_configured}
    end
  end

  defp validate_user_password(user, password) do
    case Thalamus.Domain.Entities.User.verify_password(user, password) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :invalid_password}
      {:error, _} = error -> error
    end
  end

  defp store_backup_codes(user_id, backup_codes) do
    # Store hashed backup codes in Redis
    cache_key = "mfa:backup_codes:#{UserId.to_string(user_id)}"

    hashed_codes =
      Enum.map(backup_codes, fn code ->
        :crypto.hash(:sha256, code) |> Base.encode16(case: :lower)
      end)

    case Thalamus.Infrastructure.Adapters.RedisCacheAdapter.set(
           cache_key,
           Jason.encode!(hashed_codes),
           # 1 year expiration
           31_536_000
         ) do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end
end
