defmodule ThalamusWeb.API.PasswordController do
  @moduledoc """
  Password Management API Controller.

  Handles password reset requests and confirmations.

  SOLID Principles Applied:
  - Single Responsibility: Only handles password management HTTP requests
  - Dependency Inversion: Depends on repositories through interfaces
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository
  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.{UserId, Email}

  # TODO: Inject EmailService and AuditLogger dependencies

  @doc """
  POST /api/public/password/reset

  Request a password reset for a user account.

  ## Request Body (JSON)
  {
    "email": "user@example.com"
  }

  ## Response
  - 200 OK: Password reset email sent (always returns 200 even if email not found for security)
  - 400 Bad Request: Invalid input
  - 429 Too Many Requests: Rate limit exceeded

  ## Example

      # Request
      POST /api/public/password/reset
      Content-Type: application/json

      {
        "email": "user@example.com"
      }

      # Success Response
      HTTP/1.1 200 OK
      {
        "message": "If an account with that email exists, a password reset link has been sent."
      }

  ## Security Notes
  - Always returns 200 OK to prevent email enumeration attacks
  - Rate limited to prevent abuse
  - Reset tokens expire after 1 hour
  """
  def reset(conn, params) do
    with {:ok, email_string} <- get_required_param(params, "email"),
         {:ok, email_vo} <- Email.new(email_string) do
      # Attempt to find user by email
      case PostgreSQLUserRepository.find_by_email(email_vo) do
        {:ok, user} ->
          # Generate reset token
          reset_token = generate_reset_token(user.id)

          # TODO: Send password reset email
          # EmailService.send_password_reset_email(email_vo, reset_token)
          # AuditLogger.log_password_reset_requested(user.id, %{ip_address: get_ip(conn)})

          # For now, include token in response (DEVELOPMENT ONLY)
          success_response(conn, reset_token)

        {:error, :not_found} ->
          # User not found - still return success for security
          success_response(conn, nil)

        {:error, _reason} ->
          # Any error - still return success for security
          success_response(conn, nil)
      end
    else
      {:error, :missing_parameter, param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{param}"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})
    end
  end

  @doc """
  POST /api/public/password/confirm-reset

  Confirm password reset with token and new password.

  ## Request Body (JSON)
  {
    "token": "reset_token_here",
    "password": "NewSecurePassword123!",
    "password_confirmation": "NewSecurePassword123!"
  }

  ## Response
  - 200 OK: Password reset successful
  - 400 Bad Request: Invalid or expired token, or validation error
  - 429 Too Many Requests: Rate limit exceeded

  ## Example

      # Request
      POST /api/public/password/confirm-reset
      Content-Type: application/json

      {
        "token": "abc123def456",
        "password": "MyNewSecure123!",
        "password_confirmation": "MyNewSecure123!"
      }

      # Success Response
      HTTP/1.1 200 OK
      {
        "message": "Password reset successful. You can now sign in with your new password."
      }
  """
  def confirm_reset(conn, params) do
    with {:ok, token} <- get_required_param(params, "token"),
         {:ok, password} <- get_required_param(params, "password"),
         {:ok, password_confirmation} <- get_required_param(params, "password_confirmation"),
         :ok <- validate_password_confirmation(password, password_confirmation),
         {:ok, user_id} <- decode_reset_token(token),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         {:ok, updated_user} <- User.change_password(user, password, password),
         {:ok, _saved_user} <- PostgreSQLUserRepository.save(updated_user) do
      # TODO: Audit log
      # AuditLogger.log_password_changed(user.id, %{ip_address: get_ip(conn)})

      # TODO: Send notification email
      # EmailService.send_password_changed_notification(user.email)

      # TODO: Revoke all existing sessions and tokens for security
      # TokenRepository.revoke_all_for_user(user_id)

      conn
      |> put_status(:ok)
      |> json(%{
        message: "Password reset successful. You can now sign in with your new password."
      })
    else
      {:error, :missing_parameter, param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{param}"})

      {:error, :password_mismatch} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Password and confirmation do not match"})

      {:error, :invalid_token} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid or expired reset token"})

      {:error, :not_found} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid or expired reset token"})

      {:error, :incorrect_current_password} ->
        # This shouldn't happen in password reset flow, but handle it
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Password reset failed"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Password reset failed", details: inspect(reason)})
    end
  end

  @doc """
  PUT /api/password/change

  Change password for authenticated user (requires current password).

  Requires authentication token in Authorization header.

  ## Request Body (JSON)
  {
    "current_password": "OldPassword123!",
    "new_password": "NewSecurePassword123!",
    "new_password_confirmation": "NewSecurePassword123!"
  }

  ## Response
  - 200 OK: Password changed successfully
  - 400 Bad Request: Invalid input or incorrect current password
  - 401 Unauthorized: Not authenticated
  """
  def change(conn, params) do
    with {:ok, user_id} <- get_authenticated_user_id(conn),
         {:ok, current_password} <- get_required_param(params, "current_password"),
         {:ok, new_password} <- get_required_param(params, "new_password"),
         {:ok, new_password_confirmation} <-
           get_required_param(params, "new_password_confirmation"),
         :ok <- validate_password_confirmation(new_password, new_password_confirmation),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         {:ok, updated_user} <- User.change_password(user, current_password, new_password),
         {:ok, _saved_user} <- PostgreSQLUserRepository.save(updated_user) do
      # TODO: Audit log
      # AuditLogger.log_password_changed(user.id, %{ip_address: get_ip(conn)})

      # TODO: Send notification email
      # EmailService.send_password_changed_notification(user.email)

      conn
      |> put_status(:ok)
      |> json(%{
        message: "Password changed successfully"
      })
    else
      {:error, :not_authenticated} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :missing_parameter, param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{param}"})

      {:error, :password_mismatch} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "New password and confirmation do not match"})

      {:error, :incorrect_current_password} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Current password is incorrect"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Password change failed", details: inspect(reason)})
    end
  end

  # Private helper functions

  defp success_response(conn, token) do
    response = %{
      message: "If an account with that email exists, a password reset link has been sent."
    }

    # DEVELOPMENT ONLY - include token in response
    # In production, remove this and only send via email
    response =
      if token do
        Map.put(response, :reset_token, token)
      else
        response
      end

    conn
    |> put_status(:ok)
    |> json(response)
  end

  defp get_required_param(params, key) do
    case params[key] do
      nil -> {:error, :missing_parameter, key}
      "" -> {:error, :missing_parameter, key}
      value -> {:ok, value}
    end
  end

  defp validate_password_confirmation(password, password_confirmation) do
    if password == password_confirmation do
      :ok
    else
      {:error, :password_mismatch}
    end
  end

  defp get_authenticated_user_id(conn) do
    case conn.assigns[:current_user_id] do
      nil ->
        {:error, :not_authenticated}

      user_id when is_binary(user_id) ->
        UserId.from_string(user_id)

      user_id ->
        {:ok, user_id}
    end
  end

  defp generate_reset_token(user_id) do
    # Generate a secure random token
    # In production, this should be stored in database with expiration
    user_id_string = UserId.to_string(user_id)
    timestamp = DateTime.to_unix(DateTime.utc_now())
    token_data = "#{user_id_string}:#{timestamp}"

    # Create HMAC signature
    secret_key = Application.get_env(:thalamus, :password_reset_secret, "change_me_in_production")
    signature = :crypto.mac(:hmac, :sha256, secret_key, token_data)

    # Encode token
    Base.url_encode64("#{token_data}:#{Base.encode64(signature)}", padding: false)
  end

  defp decode_reset_token(token) do
    # Decode and verify token
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded} ->
        case String.split(decoded, ":", parts: 3) do
          [user_id_string, timestamp, signature_b64] ->
            # Verify token not expired (1 hour)
            token_time = String.to_integer(timestamp)
            now = DateTime.to_unix(DateTime.utc_now())

            if now - token_time < 3600 do
              # Verify signature
              token_data = "#{user_id_string}:#{timestamp}"

              secret_key =
                Application.get_env(:thalamus, :password_reset_secret, "change_me_in_production")

              expected_signature = :crypto.mac(:hmac, :sha256, secret_key, token_data)

              case Base.decode64(signature_b64) do
                {:ok, provided_signature} ->
                  if :crypto.hash_equals(expected_signature, provided_signature) do
                    # Token valid - return user ID
                    UserId.from_string(user_id_string)
                  else
                    {:error, :invalid_token}
                  end

                :error ->
                  {:error, :invalid_token}
              end
            else
              {:error, :invalid_token}
            end

          _ ->
            {:error, :invalid_token}
        end

      :error ->
        {:error, :invalid_token}
    end
  end
end
