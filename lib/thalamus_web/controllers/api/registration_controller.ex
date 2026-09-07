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
    PostgreSQLOrganizationRepository,
    PostgreSQLOAuth2ClientRepository
  }

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, OrganizationId}
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

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
    result =
      Thalamus.Repo.transaction(fn ->
        with {:ok, email_string} <- get_required_param(params, "email"),
             {:ok, password} <- get_required_param(params, "password"),
             {:ok, password_confirmation} <- get_required_param(params, "password_confirmation"),
             :ok <- validate_password_confirmation(password, password_confirmation),
             {:ok, email_vo} <- Email.new(email_string),
             {:ok, nil} <- check_email_available(email_vo),
             {:ok, organization} <- resolve_or_create_organization(params, email_string),
             # Create user
             {:ok, user} <- create_user(email_string, password, params),
             {:ok, saved_user} <- PostgreSQLUserRepository.save(user),
             # Auto-verify user so account is active immediately
             {:ok, verified_user} <- User.verify_email(saved_user),
             {:ok, final_user} <- PostgreSQLUserRepository.save(verified_user),
             # Associate user with organization at schema level
             :ok <- associate_user_with_organization(final_user, organization),
             # Add user as member if organization exists and user is not owner
             {:ok, _org} <- add_user_to_organization_members(organization, final_user) do
          {final_user, organization}
        else
          {:error, :missing_parameter, param} ->
            Thalamus.Repo.rollback({:missing_parameter, param})

          {:error, reason} ->
            Thalamus.Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, {saved_user, organization}} ->
        # Generate verification token (kept for backwards compatibility / dev token)
        verification_token = generate_verification_token(saved_user.id)

        # Build response
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            id: UserId.to_string(saved_user.id),
            email: Email.to_string(saved_user.email),
            name: saved_user.name,
            status: "active",
            verified: true,
            organization_id: OrganizationId.to_string(organization.id)
          },
          message: "Registration successful.",
          # DEVELOPMENT / BACKWARDS COMPATIBILITY ONLY
          verification_token: verification_token
        })

      {:error, {:missing_parameter, param}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{param}"})

      {:error, :organization_not_found} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Organization not found"})

      {:error, :client_not_found} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "OAuth2 client not found"})

      {:error, :client_has_no_organization} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "OAuth2 client does not belong to an organization"})

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
         :ok <- validate_verification_token(user.id, token) do
      case User.verify_email(user) do
        {:ok, verified_user} ->
          {:ok, saved_user} = PostgreSQLUserRepository.save(verified_user)

          conn
          |> put_status(:ok)
          |> json(%{
            data: user_to_json(saved_user),
            message: "Email verified successfully. You can now sign in."
          })

        {:error, :already_verified} ->
          conn
          |> put_status(:ok)
          |> json(%{
            data: user_to_json(user),
            message: "Email address already verified."
          })

        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid user state", details: to_string(reason)})
      end
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

  defp resolve_or_create_organization(params, email_string) do
    cond do
      is_binary(params["organization_id"]) and params["organization_id"] != "" ->
        resolve_organization_by_id(params["organization_id"])

      is_binary(params["client_id"]) and params["client_id"] != "" ->
        resolve_organization_by_client_id(params["client_id"])

      is_binary(params["organization_name"]) and params["organization_name"] != "" ->
        create_new_organization(params["organization_name"], email_string)

      true ->
        create_default_personal_organization(params, email_string)
    end
  end

  defp resolve_organization_by_id(org_id_string) do
    case OrganizationId.from_string(org_id_string) do
      {:ok, org_id} ->
        case PostgreSQLOrganizationRepository.find_by_id(org_id) do
          {:ok, org} -> {:ok, org}
          {:error, :not_found} -> {:error, :organization_not_found}
          {:error, reason} -> {:error, reason}
        end

      {:error, _} ->
        {:error, :organization_not_found}
    end
  end

  defp resolve_organization_by_client_id(client_id_string) do
    case PostgreSQLOAuth2ClientRepository.find_by_client_id(client_id_string) do
      {:ok, client} ->
        if client.organization_id do
          case PostgreSQLOrganizationRepository.find_by_id(client.organization_id) do
            {:ok, org} -> {:ok, org}
            {:error, :not_found} -> {:error, :organization_not_found}
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, :client_has_no_organization}
        end

      {:error, :not_found} ->
        {:error, :client_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_new_organization(org_name, email_string) do
    with {:ok, organization} <- Organization.new(org_name, email_string, :free),
         {:ok, saved_org} <- PostgreSQLOrganizationRepository.save(organization) do
      {:ok, saved_org}
    end
  end

  defp create_default_personal_organization(params, email_string) do
    name = params["name"]

    org_name =
      if is_binary(name) and String.trim(name) != "" do
        "#{String.trim(name)}'s Organization"
      else
        [prefix | _] = String.split(email_string, "@")
        "#{prefix}'s Organization"
      end

    create_new_organization(org_name, email_string)
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
    # Get the UUIDs without prefix
    user_id_string = UserId.to_string(user.id)
    user_uuid = String.replace_prefix(user_id_string, "user_", "")
    org_id_string = OrganizationId.to_string(organization.id)
    org_uuid = String.replace_prefix(org_id_string, "org_", "")

    # Update the user schema directly with organization_id
    case Thalamus.Repo.get(UserSchema, user_uuid) do
      nil ->
        {:error, :user_not_found}

      user_schema ->
        user_schema
        |> Ecto.Changeset.change(%{organization_id: org_uuid})
        |> Thalamus.Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp add_user_to_organization_members(organization, user) do
    user_email_str = Email.to_string(user.email)
    owner_email_str = organization.owner_email && Email.to_string(organization.owner_email)

    cond do
      owner_email_str == user_email_str ->
        # User is the owner of this organization.
        # Ensure owner member in organization.members has user_id set
        updated_members =
          Enum.map(organization.members, fn member ->
            if member.role == :owner and (is_nil(member.user_id) or member.user_id == user.id) do
              %{member | user_id: user.id}
            else
              member
            end
          end)

        updated_org = %{organization | members: updated_members}
        PostgreSQLOrganizationRepository.save(updated_org)

      Enum.any?(organization.members, fn m -> m.user_id == user.id end) ->
        {:ok, organization}

      true ->
        case Organization.add_member(organization, user.id, user.email, :member) do
          {:ok, updated_org} ->
            PostgreSQLOrganizationRepository.save(updated_org)

          {:error, :member_already_exists} ->
            {:ok, organization}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp user_to_json(%User{} = user) do
    %{
      id: UserId.to_string(user.id),
      email: Email.to_string(user.email),
      name: user.name,
      status: to_string(user.status),
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
