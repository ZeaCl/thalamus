defmodule Thalamus.Application.UseCases.AuthenticateUser do
  @moduledoc """
  Use Case for authenticating a user with credentials and optional MFA.

  SOLID Principles Applied:
  - Single Responsibility: Only handles user authentication workflow
  - Dependency Inversion: Depends on ports (interfaces), not implementations
  - Open/Closed: Can be extended for new authentication methods
  """

  alias Thalamus.Application.DTOs.{AuthenticationRequest, AuthenticationResponse}
  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.Email

  @type deps :: %{
          user_repository: module(),
          audit_logger: module()
        }

  @doc """
  Executes the authentication use case.

  ## Steps:
  1. Validate and parse email
  2. Find user by email
  3. Check if user can authenticate
  4. Verify password
  5. Handle MFA if required
  6. Record authentication result
  7. Update last login if successful

  ## Examples

      iex> request = %AuthenticationRequest{email: "user@example.com", password: "SecureP@ssw0rd123"}
      iex> AuthenticateUser.execute(request, deps)
      {:ok, %AuthenticationResponse{authenticated: true}}
  """
  def execute(%AuthenticationRequest{} = request, deps) do
    with {:ok, email} <- parse_email(request.email),
         {:ok, user} <- find_user(email, deps),
         :ok <- check_can_authenticate(user),
         :ok <- verify_password(user, request.password),
         {:ok, response} <- handle_mfa(user, request.mfa_code, deps) do
      # Successful authentication
      record_success(user, deps)
      {:ok, response}
    else
      {:error, :not_found} ->
        record_failure(request.email, :user_not_found, request.context, deps)
        {:error, :invalid_credentials}

      {:error, :invalid_password} ->
        with {:ok, email} <- parse_email(request.email),
             {:ok, user} <- find_user(email, deps) do
          record_failed_attempt(user, deps)
        end

        record_failure(request.email, :invalid_password, request.context, deps)
        {:error, :invalid_credentials}

      {:error, :account_locked} = error ->
        record_failure(request.email, :account_locked, request.context, deps)
        error

      {:error, :account_suspended} = error ->
        record_failure(request.email, :account_suspended, request.context, deps)
        error

      {:error, :account_not_verified} = error ->
        record_failure(request.email, :account_not_verified, request.context, deps)
        error

      {:error, :mfa_required} = error ->
        error

      {:error, :invalid_mfa_code} = error ->
        record_failure(request.email, :invalid_mfa_code, request.context, deps)
        error

      {:error, reason} ->
        record_failure(request.email, reason, request.context, deps)
        {:error, reason}
    end
  end

  # Private functions

  defp parse_email(email_string) do
    Email.new(email_string)
  end

  defp find_user(email, %{user_repository: repo}) do
    repo.find_by_email(email)
  end

  defp check_can_authenticate(user) do
    cond do
      User.account_locked?(user) ->
        {:error, :account_locked}

      not User.can_authenticate?(user) ->
        if user.status == :pending_verification do
          {:error, :account_not_verified}
        else
          {:error, :account_suspended}
        end

      true ->
        :ok
    end
  end

  defp verify_password(user, password) do
    User.verify_password(user, password)
  end

  defp handle_mfa(user, mfa_code, _deps) do
    if User.mfa_enabled?(user) do
      if is_nil(mfa_code) do
        # MFA is required but code not provided
        mfa_token = generate_mfa_token()
        {:ok, AuthenticationResponse.mfa_required(user, mfa_token)}
      else
        # Validate MFA code
        case validate_mfa_code(user, mfa_code) do
          :ok ->
            {:ok, AuthenticationResponse.success(user)}

          {:error, _} ->
            {:error, :invalid_mfa_code}
        end
      end
    else
      # No MFA required
      {:ok, AuthenticationResponse.success(user)}
    end
  end

  defp validate_mfa_code(_user, code) do
    # TODO: Implement actual MFA validation
    # This would verify TOTP, SMS code, etc. based on the user's MFA methods
    # For now, accept any non-empty code
    if code == "" do
      {:error, :invalid_mfa_code}
    else
      :ok
    end
  end

  defp generate_mfa_token do
    # Generate a temporary token for MFA session
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  defp record_success(user, %{user_repository: repo, audit_logger: logger}) do
    # Update last login
    now = DateTime.truncate(DateTime.utc_now(), :second)
    {:ok, _updated_user} = User.record_successful_login(user)
    repo.update_last_login(user.id, now)

    # Log success
    logger.log_authentication_success(user.id, %{})
  end

  defp record_failed_attempt(user, %{user_repository: repo}) do
    {:ok, updated_user} = User.record_failed_login(user)
    repo.save(updated_user)
  end

  defp record_failure(email, reason, context, %{audit_logger: logger}) do
    logger.log_authentication_failure(email, reason, context)
  end
end
