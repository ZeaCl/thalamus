defmodule Thalamus.Application.UseCases.GenerateTokens do
  @moduledoc """
  Use Case for generating OAuth2 tokens.

  SOLID Principles Applied:
  - Single Responsibility: Only handles token generation workflow
  - Dependency Inversion: Depends on ports (interfaces)
  - Open/Closed: Can be extended for new grant types
  """

  alias Thalamus.Application.DTOs.{TokenRequest, TokenResponse}
  # Ports are referenced via deps parameter, not direct aliases

  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.ClientId

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
         {:ok, token_data} <- generate_for_grant_type(request, client, deps) do
      # Store tokens
      store_tokens(token_data, deps)

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
    with {:ok, client_id_vo} <- ClientId.new(client_id),
         {:ok, client} <- repo.find_by_id(client_id_vo),
         :ok <- check_client_active(client),
         :ok <- verify_client_secret(client, client_secret) do
      {:ok, client}
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
    access_token = generate_access_token()
    scopes = parse_scopes(request.scope)

    unless OAuth2Client.valid_scopes?(client, scopes) do
      {:error, :invalid_scope}
    else
      {:ok,
       %{
         access_token: access_token,
         token_type: "Bearer",
         expires_in: @access_token_ttl,
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
      access_token = generate_access_token()
      refresh_token = generate_refresh_token()
      scopes = auth_code_data.scopes

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
         :ok <- validate_token_ownership(stored_token, client.id) do
      # Generate new tokens
      access_token = generate_access_token()
      new_refresh_token = generate_refresh_token()

      # Revoke old refresh token (rotation)
      revoke_token(request.refresh_token, deps)

      {:ok,
       %{
         access_token: access_token,
         token_type: "Bearer",
         expires_in: @access_token_ttl,
         refresh_token: new_refresh_token,
         scope: stored_token.scope,
         user_id: stored_token.user_id,
         client_id: client.id
       }}
    end
  end

  defp generate_for_grant_type(%TokenRequest{grant_type: :password}, _client, _deps) do
    # Password grant is deprecated and should not be used
    {:error, :deprecated_grant_type}
  end

  defp validate_redirect_uri(_client, nil), do: :ok

  defp validate_redirect_uri(client, redirect_uri) do
    if OAuth2Client.valid_redirect_uri?(client, redirect_uri) do
      :ok
    else
      {:error, :invalid_redirect_uri}
    end
  end

  defp verify_authorization_code(_code, %{token_repository: _repo}) do
    # TODO: Implement actual authorization code verification
    # This would look up the code in storage and validate it
    {:ok,
     %{
       user_id: nil,
       scopes: ["openid"],
       pkce_challenge: nil
     }}
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

  defp generate_access_token do
    "at_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))
  end

  defp generate_refresh_token do
    "rt_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))
  end

  defp parse_scopes(nil), do: []
  defp parse_scopes(""), do: []
  defp parse_scopes(scope_string) when is_binary(scope_string), do: String.split(scope_string, " ")

  defp store_tokens(token_data, %{token_repository: repo}) do
    # Store access token
    repo.store(%{
      token: token_data.access_token,
      type: :access_token,
      user_id: token_data.user_id,
      client_id: token_data.client_id,
      scopes: parse_scopes(token_data.scope),
      expires_at: DateTime.add(DateTime.utc_now(), token_data.expires_in),
      revoked: false,
      created_at: DateTime.utc_now()
    })

    # Store refresh token if present
    if token_data.refresh_token do
      repo.store(%{
        token: token_data.refresh_token,
        type: :refresh_token,
        user_id: token_data.user_id,
        client_id: token_data.client_id,
        scopes: parse_scopes(token_data.scope),
        expires_at: DateTime.add(DateTime.utc_now(), @refresh_token_ttl),
        revoked: false,
        created_at: DateTime.utc_now()
      })
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
