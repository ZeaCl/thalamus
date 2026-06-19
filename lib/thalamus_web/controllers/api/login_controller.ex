defmodule ThalamusWeb.API.LoginController do
  @moduledoc """
  Public Login API Controller.

  Handles user authentication via email/password and returns OAuth2 access tokens.
  This is the API-based login (JSON) for SPAs and mobile apps, as opposed to
  the browser-based SessionController which uses HTTP sessions.

  SOLID Principles Applied:
  - Single Responsibility: Only handles API login requests
  - Dependency Inversion: Depends on Use Cases and Repositories
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLTokenRepository
  }

  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.{Email, UserId, OrganizationId}
  alias Thalamus.Infrastructure.JwtSigner

  @doc """
  POST /api/public/login

  Authenticate user with email and password, return access tokens.

  ## Request Body (JSON)
  {
    "email": "user@example.com",
    "password": "SecurePassword123!"
  }

  ## Response (200 OK)
  {
    "access_token": "at_xxx...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "refresh_token": "rt_xxx...",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "name": "User Name",
      "verified": true
    },
    "organization": {
      "id": "uuid",
      "name": "Company Name"
    }
  }

  ## Errors
  - 400 Bad Request: Missing or invalid parameters
  - 401 Unauthorized: Invalid credentials or account issues
  """
  def create(conn, params) do
    with {:ok, email_string} <- get_required_param(params, "email"),
         {:ok, password} <- get_required_param(params, "password"),
         {:ok, email} <- Email.new(email_string),
         {:ok, user} <- find_and_authenticate_user(email, password),
         :ok <- check_user_can_login(user),
         {:ok, tokens} <- generate_tokens_for_user(user),
         {:ok, organization} <- get_user_organization(user),
         :ok <- update_last_login(user) do
      # Successful login
      conn
      |> put_status(:ok)
      |> json(%{
        access_token: tokens.access_token,
        token_type: tokens.token_type,
        expires_in: tokens.expires_in,
        refresh_token: tokens.refresh_token,
        user: user_to_json(user),
        organization: organization_to_json(organization)
      })
    else
      {:error, :missing_parameter, param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "missing_parameter",
          error_description: "Missing required parameter: #{param}"
        })

      {:error, :invalid_email} ->
        # Don't reveal which part failed (email vs password) for security
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "invalid_credentials",
          error_description: "Invalid email or password"
        })

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "invalid_credentials",
          error_description: "Invalid email or password"
        })

      {:error, :not_found} ->
        # Don't reveal that user doesn't exist
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "invalid_credentials",
          error_description: "Invalid email or password"
        })

      {:error, :account_locked} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "account_locked",
          error_description: "Account is locked due to too many failed login attempts"
        })

      {:error, :account_suspended} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "account_suspended",
          error_description: "Account has been suspended"
        })

      {:error, :account_not_verified} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "account_not_verified",
          error_description: "Please verify your email address before logging in"
        })

      {:error, :mfa_required} ->
        # TODO: Implement MFA flow
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "mfa_required",
          error_description: "Multi-factor authentication is required"
        })

      {:error, reason} ->
        require Logger
        Logger.error("Login failed: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "login_failed",
          error_description: "Unable to complete login"
        })
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

  defp find_and_authenticate_user(email, password) do
    case PostgreSQLUserRepository.find_by_email(email) do
      {:ok, user} ->
        # Verify password
        case User.verify_password(user, password) do
          :ok ->
            {:ok, user}

          {:error, :invalid_password} ->
            # Record failed login attempt
            {:ok, updated_user} = User.record_failed_login(user)
            PostgreSQLUserRepository.save(updated_user)
            {:error, :invalid_credentials}
        end

      {:error, :not_found} ->
        # Perform dummy password check to prevent timing attacks
        # This ensures the response time is similar whether user exists or not
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end

  defp check_user_can_login(user) do
    cond do
      User.account_locked?(user) ->
        {:error, :account_locked}

      user.status == :suspended ->
        {:error, :account_suspended}

      user.status == :pending_verification ->
        {:error, :account_not_verified}

      user.status == :deactivated ->
        {:error, :account_suspended}

      User.mfa_enabled?(user) ->
        # TODO: Implement full MFA flow
        # For now, we'll return error if MFA is enabled
        {:error, :mfa_required}

      user.status == :active ->
        :ok

      true ->
        {:error, :account_suspended}
    end
  end

  defp generate_tokens_for_user(user) do
    # Generate tokens directly for authenticated user
    # We don't use the full OAuth2 flow since the user is already authenticated
    generate_tokens_directly(user)
  end

  defp generate_tokens_directly(user) do
    # Generate JWT access token
    access_token =
      JwtSigner.sign_access_token(%{
        user_id: user.id,
        client_id: "internal_login",
        scope: Enum.join(get_default_user_scopes(), " "),
        expires_in: 3600,
        aud: "internal_login"
      })

    refresh_token = generate_refresh_token()

    # Get user's organization
    organization_id =
      case get_user_organization(user) do
        {:ok, org} when not is_nil(org) -> org.id
        _ -> nil
      end

    # Use a fixed UUID for internal client
    internal_client_uuid = "00000000-0000-0000-0000-000000000001"

    # Store access token
    store_token(%{
      token: access_token,
      type: :access_token,
      user_id: user.id,
      client_id: internal_client_uuid,
      organization_id: organization_id,
      scopes: get_default_user_scopes(),
      expires_at: DateTime.add(DateTime.utc_now(), 3600),
      revoked: false
    })

    # Store refresh token
    store_token(%{
      token: refresh_token,
      type: :refresh_token,
      user_id: user.id,
      client_id: internal_client_uuid,
      organization_id: organization_id,
      scopes: get_default_user_scopes(),
      expires_at: DateTime.add(DateTime.utc_now(), 2_592_000),
      revoked: false
    })

    {:ok,
     %{
       access_token: access_token,
       token_type: "Bearer",
       expires_in: 3600,
       refresh_token: refresh_token,
       scope: Enum.join(get_default_user_scopes(), " ")
     }}
  end

  defp generate_refresh_token do
    "rt_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))
  end

  defp store_token(token_data) do
    PostgreSQLTokenRepository.store(token_data)
  end

  defp get_default_user_scopes do
    # Default scopes for authenticated users
    # Includes standard OIDC scopes + Campaigns-specific scopes
    [
      "openid",
      "profile",
      "email",
      # Campaigns scopes
      "campaigns:read",
      "campaigns:write",
      "campaigns:sync",
      "leads:read",
      "leads:write",
      "meta:read",
      "meta:write"
    ]
  end

  # Unused legacy functions - kept for reference
  # These were used in a previous implementation and may be needed in future
  # defp get_or_create_internal_client do
  #   case PostgreSQLOAuth2ClientRepository.find_by_client_id(@internal_client_id) do
  #     {:ok, client} -> client
  #     {:error, :not_found} -> create_internal_client()
  #   end
  # end
  #
  # defp create_internal_client do
  #   alias Thalamus.Domain.Entities.OAuth2Client
  #   alias Thalamus.Domain.ValueObjects.{ClientId, OrganizationId, GrantType}
  #   {:ok, org_id} = get_or_create_system_organization()
  #   {:ok, client_id_vo} = ClientId.generate()
  #   {:ok, grant_password} = GrantType.new(:password)
  #   {:ok, grant_refresh} = GrantType.new(:refresh_token)
  #   scopes = get_default_user_scopes()
  #   {:ok, client} = OAuth2Client.new(%{
  #     id: client_id_vo,
  #     organization_id: org_id,
  #     name: "Thalamus Internal API Login",
  #     client_type: :confidential,
  #     grant_types: [grant_password, grant_refresh],
  #     redirect_uris: [],
  #     allowed_scopes: scopes,
  #     is_active: true,
  #     trusted: true
  #   })
  #   case PostgreSQLOAuth2ClientRepository.save(client) do
  #     {:ok, saved_client} -> saved_client
  #     {:error, _} -> client
  #   end
  # end
  #
  # defp get_or_create_system_organization do
  #   OrganizationId.generate()
  # end

  defp get_user_organization(user) do
    # Get organization using the organization_id from user
    case PostgreSQLOrganizationRepository.find_by_user_id(user.id) do
      {:ok, organization} ->
        {:ok, organization}

      {:error, :not_found} ->
        # User doesn't have an organization yet
        {:ok, nil}

      {:error, _reason} ->
        {:ok, nil}
    end
  end

  defp update_last_login(user) do
    # Update last login timestamp
    {:ok, updated_user} = User.record_successful_login(user)
    PostgreSQLUserRepository.save(updated_user)
    :ok
  end

  defp user_to_json(%User{} = user) do
    %{
      id: UserId.to_string(user.id),
      email: Email.to_string(user.email),
      name: user.name,
      verified: !is_nil(user.verified_at),
      verified_at: user.verified_at,
      created_at: user.created_at
    }
  end

  defp organization_to_json(nil) do
    nil
  end

  defp organization_to_json(organization) do
    %{
      id: OrganizationId.to_string(organization.id),
      name: organization.name,
      created_at: organization.created_at
    }
  end
end
