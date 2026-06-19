defmodule Thalamus.Application.UseCases.GenerateTokens do
  @moduledoc """
  Use Case for generating OAuth2 tokens.

  SOLID Principles Applied:
  - Single Responsibility: Only handles token generation workflow
  - Dependency Inversion: Depends on ports (interfaces)
  - Open/Closed: Can be extended for new grant types
  """

  alias Thalamus.Application.DTOs.{TokenRequest, TokenResponse}
  alias Thalamus.Infrastructure.JwtSigner
  # Ports are referenced via deps parameter, not direct aliases

  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash}

  @type deps :: %{
          oauth2_client_repository: module(),
          user_repository: module(),
          token_repository: module(),
          audit_logger: module()
        }

  @access_token_ttl 3600
  # 1 hour
  @refresh_token_ttl 2_592_000
  # 30 days
  @service_token_ttl 604_800
  # 7 days for service accounts (machine-to-machine)

  @doc """
  Executes the token generation use case.

  Supports multiple OAuth2 grant types:
  - authorization_code
  - client_credentials
  - refresh_token
  - password (legacy)

  ## Examples

      iex> request = %TokenRequest{grant_type: :client_credentials, client_id: "client_123", ...}
      iex> GenerateTokens.execute(request, deps)
      {:ok, %TokenResponse{access_token: "...", expires_in: 3600}}
  """
  def execute(%TokenRequest{} = request, deps) do
    with {:ok, client} <- authenticate_client(request, deps),
         :ok <- validate_grant_type(client, request.grant_type),
         {:ok, token_data} <- generate_for_grant_type(request, client, deps),
         :ok <- store_tokens(token_data, deps) do
      # Audit log
      log_token_generation(client, token_data, deps)

      # Build response
      response = build_response(token_data)
      {:ok, response}
    end
  end

  # Private functions

  defp authenticate_client(
         %TokenRequest{client_id: client_id, client_secret: client_secret},
         %{oauth2_client_repository: repo}
       ) do
    # Note: client_id is the public OAuth2 client identifier (e.g., "platform_web")
    # NOT the internal database UUID. We must use find_by_client_id(), not find_by_id()
    case repo.find_by_client_id(client_id) do
      {:ok, client} ->
        with :ok <- check_client_active(client),
             :ok <- verify_client_secret(client, client_secret) do
          {:ok, client}
        end

      {:error, _} = error ->
        error
    end
  end

  defp check_client_active(%OAuth2Client{is_active: true}), do: :ok
  defp check_client_active(_), do: {:error, :client_inactive}

  defp verify_client_secret(%OAuth2Client{client_type: :public}, nil), do: :ok

  defp verify_client_secret(%OAuth2Client{} = client, secret) when is_binary(secret) do
    OAuth2Client.verify_secret(client, secret)
  end

  defp verify_client_secret(_, _), do: {:error, :invalid_client_secret}

  defp validate_grant_type(client, grant_type) do
    if OAuth2Client.supports_grant_type?(client, grant_type) do
      :ok
    else
      {:error, :unsupported_grant_type}
    end
  end

  defp generate_for_grant_type(
         %TokenRequest{grant_type: :client_credentials} = request,
         client,
         _deps
       ) do
    # Machine-to-machine flow - no user involved
    scopes = parse_scopes(request.scope)
    ttl = if is_service_client?(client), do: @service_token_ttl, else: @access_token_ttl

    unless OAuth2Client.valid_scopes?(client, scopes) do
      {:error, :invalid_scope}
    else
      access_token =
        generate_jwt_access_token(%{
          user_id: nil,
          client_id: client_id_string(client),
          scope: Enum.join(scopes, " "),
          expires_in: ttl,
          aud: client_id_string(client)
        })

      {:ok,
       %{
         access_token: access_token,
         token_type: "Bearer",
         expires_in: ttl,
         refresh_token: nil,
         scope: Enum.join(scopes, " "),
         user_id: nil,
         client_id: client.id
       }}
    end
  end

  defp generate_for_grant_type(
         %TokenRequest{grant_type: :authorization_code} = request,
         client,
         deps
       ) do
    # Authorization code flow
    with :ok <- validate_redirect_uri(client, request.redirect_uri),
         {:ok, auth_code_data} <- verify_authorization_code(request.code, deps),
         :ok <- verify_pkce(request.code_verifier, auth_code_data),
         {:ok, user} <- get_user(auth_code_data.user_id, deps) do
      scopes = auth_code_data.scopes
      refresh_token = generate_refresh_token()

      access_token =
        generate_jwt_access_token(%{
          user_id: user.id,
          client_id: client_id_string(client),
          scope: Enum.join(scopes, " "),
          expires_in: @access_token_ttl,
          aud: client_id_string(client),
          sub: UserId.to_string(user.id),
          name: user.name,
          email: Email.to_string(user.email),
          is_agent: user.is_agent
        })

      # Revoke authorization code
      revoke_token(request.code, deps)

      {:ok,
       %{
         access_token: access_token,
         token_type: "Bearer",
         expires_in: @access_token_ttl,
         refresh_token: refresh_token,
         scope: Enum.join(scopes, " "),
         user_id: user.id,
         client_id: client.id
       }}
    end
  end

  defp generate_for_grant_type(
         %TokenRequest{grant_type: :refresh_token} = request,
         client,
         deps
       ) do
    with {:ok, stored_token} <- find_refresh_token(request.refresh_token, deps),
         :ok <- validate_token_ownership(stored_token, client.id),
         {:ok, user} <- get_user(stored_token.user_id, deps) do
      # Generate new tokens
      scopes_list = stored_token.scopes || []
      new_refresh_token = generate_refresh_token()

      access_token =
        generate_jwt_access_token(%{
          user_id: user.id,
          client_id: client_id_string(client),
          scope: Enum.join(scopes_list, " "),
          expires_in: @access_token_ttl,
          aud: client_id_string(client),
          sub: UserId.to_string(user.id),
          name: user.name,
          email: Email.to_string(user.email),
          is_agent: user.is_agent
        })

      # Revoke old refresh token (rotation)
      revoke_token(request.refresh_token, deps)

      {:ok,
       %{
         access_token: access_token,
         token_type: "Bearer",
         expires_in: @access_token_ttl,
         refresh_token: new_refresh_token,
         scope: Enum.join(stored_token.scopes || [], " "),
         user_id: user.id,
         client_id: client.id
       }}
    end
  end

  defp generate_for_grant_type(%TokenRequest{grant_type: :password} = request, client, deps) do
    # Resource Owner Password Credentials grant (RFC 6749 Section 4.3)
    %{username: email, password: password, scope: scope} = request

    with {:ok, user} <- authenticate_user(email, password, deps),
         :ok <- validate_user_active(user) do
      scopes = parse_scopes(scope)
      # If no scopes requested, default to openid profile email
      scopes = if scopes == [], do: ["openid", "profile", "email"], else: scopes
      refresh_token = generate_refresh_token()

      access_token =
        generate_jwt_access_token(%{
          user_id: user.id,
          client_id: client_id_string(client),
          scope: Enum.join(scopes, " "),
          expires_in: @access_token_ttl,
          aud: client_id_string(client),
          sub: UserId.to_string(user.id),
          name: user.name,
          email: Email.to_string(user.email),
          is_agent: user.is_agent,
          organization_id: user.organization_id
        })

      {:ok,
       %{
         access_token: access_token,
         token_type: "Bearer",
         expires_in: @access_token_ttl,
         refresh_token: refresh_token,
         scope: Enum.join(scopes, " "),
         user_id: user.id,
         client_id: client_id_string(client)
       }}
    end
  end

  defp is_service_client?(client) do
    grants = client.grant_types || []
    # Service clients only have client_credentials grant, no user-facing grants
    grant_atoms = Enum.map(grants, fn g -> g.type end)
    grant_atoms == [:client_credentials]
  end

  defp authenticate_user(nil, _password, _deps), do: {:error, :invalid_grant}
  defp authenticate_user(_email, nil, _deps), do: {:error, :invalid_grant}

  defp authenticate_user(email, password, %{user_repository: repo}) when is_binary(email) do
    case Email.new(email) do
      {:ok, email_vo} ->
        case repo.find_by_email(email_vo) do
          {:ok, user} ->
            case PasswordHash.verify(user.password_hash, password) do
              :ok -> {:ok, user}
              {:error, _} -> {:error, :invalid_grant}
            end

          {:error, :not_found} ->
            Bcrypt.no_user_verify()
            {:error, :invalid_grant}
        end

      {:error, _} ->
        {:error, :invalid_grant}
    end
  end

  defp validate_user_active(%{status: :active}), do: :ok
  defp validate_user_active(_), do: {:error, :invalid_grant}

  defp validate_redirect_uri(_client, nil), do: :ok

  defp validate_redirect_uri(client, redirect_uri) do
    if OAuth2Client.valid_redirect_uri?(client, redirect_uri) do
      :ok
    else
      {:error, :invalid_redirect_uri}
    end
  end

  defp verify_authorization_code(code, %{token_repository: repo}) do
    # Look up the authorization code in the repository
    case repo.find(code) do
      {:ok, token_data} ->
        # Validate token type
        if token_data.type != :authorization_code do
          {:error, :invalid_grant}
        else
          # Check if expired
          now = DateTime.utc_now()

          if DateTime.compare(token_data.expires_at, now) == :lt do
            {:error, :expired_authorization_code}
          else
            # Return the authorization code data
            {:ok,
             %{
               user_id: token_data.user_id,
               client_id: token_data.client_id,
               scopes: token_data.scopes,
               pkce_challenge: Map.get(token_data, :code_challenge)
             }}
          end
        end

      {:error, :not_found} ->
        {:error, :invalid_grant}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_pkce(_verifier, %{pkce_challenge: nil}), do: :ok

  defp verify_pkce(verifier, %{pkce_challenge: challenge}) when is_binary(verifier) do
    # Verify PKCE challenge
    computed = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    if computed == challenge do
      :ok
    else
      {:error, :invalid_pkce_verifier}
    end
  end

  defp verify_pkce(nil, %{pkce_challenge: _challenge}), do: {:error, :pkce_verifier_required}

  defp get_user(nil, _deps), do: {:ok, nil}

  defp get_user(user_id, %{user_repository: repo}) do
    repo.find_by_id(user_id)
  end

  defp find_refresh_token(token, %{token_repository: repo}) do
    repo.find(token)
  end

  defp validate_token_ownership(token, client_id) do
    if token.client_id == client_id do
      :ok
    else
      {:error, :token_client_mismatch}
    end
  end

  defp revoke_token(token, %{token_repository: repo}) do
    repo.revoke(token)
  end

  defp generate_jwt_access_token(claims) do
    JwtSigner.sign_access_token(claims)
  end

  defp client_id_string(client) do
    if is_struct(client.id) do
      to_string(client.id)
    else
      client.id
    end
    |> String.replace_prefix("client_", "")
  end

  defp generate_refresh_token do
    "rt_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))
  end

  defp parse_scopes(nil), do: []
  defp parse_scopes(""), do: []

  defp parse_scopes(scope_string) when is_binary(scope_string),
    do: String.split(scope_string, " ")

  defp store_tokens(token_data, %{token_repository: repo}) do
    # Extract UUID from ClientId value object if needed (removes "client_" prefix)
    client_uuid =
      if is_struct(token_data.client_id) do
        token_data.client_id.value |> String.replace_prefix("client_", "")
      else
        token_data.client_id
      end

    # Store access token
    with :ok <-
           repo.store(%{
             token: token_data.access_token,
             type: :access_token,
             user_id: token_data.user_id,
             client_id: client_uuid,
             scopes: parse_scopes(token_data.scope),
             expires_at: DateTime.add(DateTime.utc_now(), token_data.expires_in),
             revoked: false,
             created_at: DateTime.utc_now()
           }) do
      # Store refresh token if present
      if token_data.refresh_token do
        repo.store(%{
          token: token_data.refresh_token,
          type: :refresh_token,
          user_id: token_data.user_id,
          client_id: client_uuid,
          scopes: parse_scopes(token_data.scope),
          expires_at: DateTime.add(DateTime.utc_now(), @refresh_token_ttl),
          revoked: false,
          created_at: DateTime.utc_now()
        })
      end

      :ok
    else
      {:error, reason} ->
        require Logger
        Logger.error("Failed to store access token: #{inspect(reason)}")
        {:error, :token_storage_failed}
    end
  end

  defp log_token_generation(client, token_data, %{audit_logger: logger}) do
    if token_data.user_id do
      logger.log_token_generated(token_data.user_id, client.id, %{})
    else
      logger.log_client_event(client.id, :token_generated, %{})
    end
  end

  defp build_response(token_data) do
    TokenResponse.success(
      token_data.access_token,
      token_data.expires_in,
      token_data.refresh_token,
      token_data.scope
    )
  end
end
