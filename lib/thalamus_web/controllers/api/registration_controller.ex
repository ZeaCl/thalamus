defmodule ThalamusWeb.API.RegistrationController do
  @moduledoc """
  User Registration API Controller.

  Handles new user registration and email verification.

  SOLID Principles Applied:
  - Single Responsibility: Only handles user registration HTTP requests
  - Dependency Inversion: Depends on repositories through interfaces
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository
  }

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, OrganizationId}

  # TODO: Inject EmailService dependency
  # For now, we'll skip email sending

  @doc """
  POST /api/public/register

  Register a new user account.

  ## Request Body (JSON)
  {
    "email": "user@example.com",
    "password": "SecurePassword123!",
    "password_confirmation": "SecurePassword123!",
    "name": "User Full Name",
    "organization_name": "Company Name" // Optional
  }

  ## Response
  - 201 Created: User registered successfully
  - 400 Bad Request: Invalid input or validation error
  - 409 Conflict: Email already exists

  ## Example

      # Request
      POST /api/public/register
      Content-Type: application/json

      {
        "email": "newuser@example.com",
        "password": "MySecure123!",
        "password_confirmation": "MySecure123!"
      }

      # Success Response
      HTTP/1.1 201 Created
      {
        "data": {
          "id": "user_abc123",
          "email": "newuser@example.com",
          "status": "pending_verification",
          "verified": false
        },
        "message": "Registration successful. Please check your email to verify your account."
      }
  """
  def create(conn, params) do
    with {:ok, email_string} <- get_required_param(params, "email"),
         {:ok, password} <- get_required_param(params, "password"),
         {:ok, password_confirmation} <- get_required_param(params, "password_confirmation"),
         :ok <- validate_password_confirmation(password, password_confirmation),
         {:ok, email_vo} <- Email.new(email_string),
         {:ok, nil} <- check_email_available(email_vo),
         # Create user first (without organization)
         {:ok, user} <- create_user(email_string, password, params),
         {:ok, saved_user} <- PostgreSQLUserRepository.save(user),
         # Now create organization with user as owner (if organization_name provided)
         {:ok, organization} <- create_organization_if_provided(params, saved_user),
         # Associate user with organization if created
         :ok <- associate_user_with_organization(saved_user, organization) do
      # Generate verification token
      verification_token = generate_verification_token(saved_user.id)

      # TODO: Send verification email
      # EmailService.send_verification_email(saved_user.email, verification_token)

      # Build response
      conn
      |> put_status(:created)
      |> json(%{
        data: %{
          id: UserId.to_string(saved_user.id),
          email: Email.to_string(saved_user.email),
          status: "pending_verification",
          verified: false
        },
        message:
          "Registration successful. Please check your email for verification instructions.",
        # DEVELOPMENT ONLY - remove in production
        verification_token: verification_token
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

      {:error, :email_already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Email address already exists"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Validation failed", details: errors})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Registration failed", details: inspect(reason)})
    end
  end

  @doc """
  POST /api/public/verify-email

  Verify user email address with verification token.

  ## Request Body (JSON)
  {
    "email": "user@example.com",
    "token": "verification_token_here"
  }

  ## Response
  - 200 OK: Email verified successfully
  - 400 Bad Request: Invalid or expired token
  - 404 Not Found: User not found

  ## Example

      # Request
      POST /api/public/verify-email
      Content-Type: application/json

      {
        "email": "newuser@example.com",
        "token": "abc123def456"
      }

      # Success Response
      HTTP/1.1 200 OK
      {
        "data": {
          "id": "user_abc123",
          "email": "newuser@example.com",
          "status": "active",
          "verified": true,
          "verified_at": "2025-10-26T10:30:00Z"
        },
        "message": "Email verified successfully. You can now sign in."
      }
  """
  def verify_email(conn, params) do
    with {:ok, email_string} <- get_required_param(params, "email"),
         {:ok, token} <- get_required_param(params, "token"),
         {:ok, email_vo} <- Email.new(email_string),
         {:ok, user} <- PostgreSQLUserRepository.find_by_email(email_vo),
         :ok <- validate_verification_token(user.id, token),
         {:ok, verified_user} <- User.verify_email(user),
         {:ok, saved_user} <- PostgreSQLUserRepository.save(verified_user) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: user_to_json(saved_user),
        message: "Email verified successfully. You can now sign in."
      })
    else
      {:error, :missing_parameter, param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{param}"})

      {:error, :not_found} ->
        # Return invalid token instead of not found (prevent enumeration)
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid or expired verification token"})

      {:error, :invalid_token} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid or expired verification token"})

      {:error, :already_verified} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Email address already verified"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Verification failed", details: inspect(reason)})
    end
  end

  @doc """
  POST /api/public/resend-verification

  Resend verification email to user.

  ## Request Body (JSON)
  {
    "email": "user@example.com"
  }

  ## Response
  - 200 OK: Verification email sent
  - 400 Bad Request: Email already verified
  - 404 Not Found: User not found
  - 429 Too Many Requests: Rate limit exceeded
  """
  def resend_verification(conn, params) do
    with {:ok, email_string} <- get_required_param(params, "email") do
      # Try to validate email format
      case Email.new(email_string) do
        {:error, _} ->
          # Invalid email format
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid email format"})

        {:ok, email_vo} ->
          # Try to find user - but don't reveal if they exist or not (prevent enumeration)
          case PostgreSQLUserRepository.find_by_email(email_vo) do
            {:ok, user} ->
              case check_not_verified(user) do
                :ok ->
                  # Generate new verification token
                  verification_token = generate_verification_token(user.id)

                  # TODO: Send verification email
                  # EmailService.send_verification_email(email_vo, verification_token)

                  conn
                  |> put_status(:ok)
                  |> json(%{
                    message:
                      "If this email is registered and unverified, a verification email will be sent.",
                    # DEVELOPMENT ONLY - remove in production
                    verification_token: verification_token
                  })

                {:error, :already_verified} ->
                  # Return generic success to prevent enumeration
                  conn
                  |> put_status(:ok)
                  |> json(%{
                    message:
                      "If this email is registered and unverified, a verification email will be sent."
                  })
              end

            {:error, :not_found} ->
              # Return generic success to prevent enumeration (don't reveal user doesn't exist)
              conn
              |> put_status(:ok)
              |> json(%{
                message:
                  "If this email is registered and unverified, a verification email will be sent."
              })

            {:error, _} ->
              # Return generic success to prevent enumeration
              conn
              |> put_status(:ok)
              |> json(%{
                message:
                  "If this email is registered and unverified, a verification email will be sent."
              })
          end
      end
    else
      {:error, :missing_parameter, param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{param}"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to process request", details: inspect(reason)})
    end
  end

  # Private helper functions

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

  defp check_email_available(email) do
    case PostgreSQLUserRepository.find_by_email(email) do
      {:ok, _user} ->
        {:error, :email_already_exists}

      {:error, :not_found} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_not_verified(user) do
    if is_nil(user.verified_at) do
      :ok
    else
      {:error, :already_verified}
    end
  end

  defp generate_verification_token(user_id) do
    # Generate a secure random token
    # In production, this should be stored in database with expiration
    user_id_string = UserId.to_string(user_id)
    token_data = "#{user_id_string}:#{DateTime.to_unix(DateTime.utc_now())}"

    # Create HMAC signature
    secret_key =
      Application.get_env(:thalamus, :verification_token_secret, "change_me_in_production")

    signature = :crypto.mac(:hmac, :sha256, secret_key, token_data)

    # Encode token
    Base.url_encode64("#{token_data}:#{Base.encode64(signature)}", padding: false)
  end

  defp validate_verification_token(user_id, token) do
    # Decode and verify token
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded} ->
        case String.split(decoded, ":", parts: 3) do
          [token_user_id, timestamp, signature_b64] ->
            # Verify user ID matches
            if token_user_id == UserId.to_string(user_id) do
              # Verify token not expired (24 hours)
              token_time = String.to_integer(timestamp)
              now = DateTime.to_unix(DateTime.utc_now())

              if now - token_time < 86400 do
                # Verify signature
                token_data = "#{token_user_id}:#{timestamp}"

                secret_key =
                  Application.get_env(
                    :thalamus,
                    :verification_token_secret,
                    "change_me_in_production"
                  )

                expected_signature = :crypto.mac(:hmac, :sha256, secret_key, token_data)

                case Base.decode64(signature_b64) do
                  {:ok, provided_signature} ->
                    if :crypto.hash_equals(expected_signature, provided_signature) do
                      :ok
                    else
                      {:error, :invalid_token}
                    end

                  :error ->
                    {:error, :invalid_token}
                end
              else
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

  defp create_organization_if_provided(params, user) do
    require Logger

    Logger.debug(
      "create_organization_if_provided called with params: #{inspect(params)}, user_id: #{inspect(user.id)}"
    )

    case params["organization_name"] do
      nil ->
        Logger.debug("No organization_name provided")
        {:ok, nil}

      "" ->
        Logger.debug("Empty organization_name provided")
        {:ok, nil}

      org_name when is_binary(org_name) ->
        Logger.debug(
          "Creating organization with name: #{org_name}, owner_email: #{inspect(user.email)}"
        )

        # Create new organization with user as owner
        # Use the convenience function that takes strings
        with {:ok, organization} <- Organization.new(org_name, Email.to_string(user.email)),
             {:ok, saved_org} <- PostgreSQLOrganizationRepository.save(organization) do
          Logger.debug("Organization created successfully: #{inspect(saved_org)}")
          {:ok, saved_org}
        else
          {:error, reason} = error ->
            Logger.error("Failed to create organization: #{inspect(reason)}")
            error
        end
    end
  end

  defp create_user(email_string, password, params) do
    name = params["name"]

    require Logger
    Logger.debug("create_user called with email=#{email_string}, name=#{inspect(name)}")

    with {:ok, user_id} <- UserId.generate(),
         {:ok, email} <- Email.new(email_string),
         {:ok, password_hash} <- Thalamus.Domain.ValueObjects.PasswordHash.from_password(password) do
      Logger.debug(
        "About to call User.new with id=#{inspect(user_id)}, email=#{inspect(email)}, name=#{inspect(name)}"
      )

      result =
        User.new(%{
          id: user_id,
          email: email,
          name: name,
          password_hash: password_hash
        })

      # Debug logging
      case result do
        {:error, reason} ->
          Logger.error(
            "User.new failed: #{inspect(reason)}, inputs: id=#{inspect(user_id)}, email=#{inspect(email)}, name=#{inspect(name)}, password_hash=present"
          )

        {:ok, user} ->
          Logger.debug("User.new succeeded: #{inspect(user)}")
      end

      result
    else
      {:error, reason} = error ->
        Logger.error("create_user failed in with: #{inspect(reason)}")
        error
    end
  end

  defp associate_user_with_organization(_user, nil), do: :ok

  defp associate_user_with_organization(user, organization) do
    alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

    # Get the UUID without prefix
    user_id_string = UserId.to_string(user.id)
    user_uuid = String.replace_prefix(user_id_string, "user_", "")
    org_id_string = OrganizationId.to_string(organization.id)

    # Update the user schema directly with organization_id
    case Thalamus.Repo.get(UserSchema, user_uuid) do
      nil ->
        {:error, :user_not_found}

      user_schema ->
        user_schema
        |> Ecto.Changeset.change(%{organization_id: org_id_string})
        |> Thalamus.Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp user_to_json(%User{} = user) do
    %{
      id: UserId.to_string(user.id),
      email: Email.to_string(user.email),
      name: user.name,
      verified: !is_nil(user.verified_at),
      created_at: user.created_at
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
