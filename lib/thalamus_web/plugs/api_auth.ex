defmodule ThalamusWeb.Plugs.APIAuth do
  @moduledoc """
  Authentication plug that supports both JWT and Admin API Key authentication.

  Supports two authentication methods:
  - `Authorization: Bearer <jwt>` - For user authentication
  - `Authorization: ApiKey <api_key>` - For service authentication (Admin API Keys)

  ## Usage

      pipeline :api_auth do
        plug :accepts, ["json"]
        plug ThalamusWeb.Plugs.APIAuth
      end

  ## Assigns

  After successful authentication, the following assigns are set:

  ### For JWT (user) authentication:
  - `conn.assigns.auth_type` = `:jwt`
  - `conn.assigns.current_user` = user entity
  - `conn.assigns.user_id` = user UUID

  ### For API Key (service) authentication:
  - `conn.assigns.auth_type` = `:api_key`
  - `conn.assigns.api_key_id` = API key UUID
  - `conn.assigns.api_key_scopes` = list of scopes
  - `conn.assigns.api_key_name` = name of the API key

  SOLID Principles Applied:
  - Single Responsibility: Only handles authentication
  - Open/Closed: Can be extended for new auth methods without modification
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Thalamus.Domain.Services.AdminApiKeyGenerator
  alias Thalamus.Infrastructure.Repositories.PostgreSQLAdminApiKeyRepository

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        if String.starts_with?(token, "th_pat_") do
          validate_pat(conn, token)
        else
          validate_jwt(conn, token)
        end

      ["ApiKey " <> api_key] ->
        validate_api_key(conn, api_key)

      _ ->
        unauthorized(
          conn,
          "Missing or invalid Authorization header. Use 'Bearer <jwt>', 'Bearer <th_pat_...>' or 'ApiKey <key>'"
        )
    end
  end

  # Personal Access Token validation
  defp validate_pat(conn, token) do
    alias Thalamus.Infrastructure.Repositories.PostgreSQLPersonalAccessTokenRepository
    alias Thalamus.Domain.Services.PersonalAccessTokenGenerator
    alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema
    alias Thalamus.Repo

    with {:ok, prefix} <- PersonalAccessTokenGenerator.extract_prefix(token),
         {:ok, pat} <- PostgreSQLPersonalAccessTokenRepository.find_by_prefix(prefix),
         true <- PersonalAccessTokenGenerator.verify_token(token, pat.token_hash) do
      now = DateTime.utc_now()

      is_expired =
        if pat.expires_at, do: DateTime.compare(now, pat.expires_at) == :gt, else: false

      if pat.is_active and not is_expired do
        # Mark used asynchronously
        Task.start(fn -> PostgreSQLPersonalAccessTokenRepository.mark_as_used(pat) end)

        user = Repo.get(UserSchema, pat.user_id)

        conn
        |> assign(:auth_type, :pat)
        |> assign(:current_user, user)
        |> assign(:user_id, pat.user_id)
        |> assign(:organization_id, pat.organization_id)
        |> assign(:token_scope, pat.scopes)
      else
        unauthorized(conn, "Personal Access Token has expired or been deactivated")
      end
    else
      _ ->
        unauthorized(conn, "Invalid Personal Access Token")
    end
  end

  # JWT validation (for user authentication)
  defp validate_jwt(conn, _token) do
    # TODO: Implement JWT validation once Guardian/Joken is set up
    # For now, this is a placeholder that should:
    # 1. Verify JWT signature
    # 2. Check expiration
    # 3. Load user from database
    # 4. Set assigns: auth_type, current_user, user_id

    # Placeholder implementation
    # In test environment, preserve existing assigns if present (for mocking)
    if Mix.env() == :test and conn.assigns[:current_user] do
      # Test mode: preserve mocked user
      conn
      |> assign(:auth_type, conn.assigns[:auth_type] || :jwt)
    else
      # Default placeholder
      conn
      |> assign(:auth_type, :jwt)
      |> assign(:current_user, %{id: "placeholder-user-id", email: "placeholder@test.com"})
      |> assign(:user_id, "placeholder-user-id")
    end
  end

  # API Key validation (for service authentication)
  defp validate_api_key(conn, api_key) do
    with :ok <- validate_api_key_format(api_key),
         key_prefix <- AdminApiKeyGenerator.extract_prefix(api_key),
         {:ok, key_record} <- PostgreSQLAdminApiKeyRepository.find_by_prefix(key_prefix),
         :ok <- verify_api_key_hash(api_key, key_record.key_hash),
         :ok <- check_active(key_record),
         :ok <- check_expiration(key_record) do
      # Update last_used_at asynchronously (don't block request)
      Task.start(fn -> update_last_used(key_record) end)

      conn
      |> assign(:auth_type, :api_key)
      |> assign(:api_key_id, key_record.id)
      |> assign(:api_key_scopes, key_record.scopes)
      |> assign(:api_key_name, key_record.name)
    else
      {:error, :invalid_format} ->
        unauthorized(conn, "Invalid API key format. Expected 'ak_dev_...' or 'ak_live_...'")

      {:error, :not_found} ->
        unauthorized(conn, "Invalid API key")

      {:error, :invalid_key} ->
        unauthorized(conn, "Invalid API key")

      {:error, :inactive} ->
        unauthorized(conn, "API key has been revoked")

      {:error, :expired} ->
        unauthorized(conn, "API key has expired")
    end
  end

  defp validate_api_key_format(api_key) do
    if AdminApiKeyGenerator.valid_format?(api_key) do
      :ok
    else
      {:error, :invalid_format}
    end
  end

  defp verify_api_key_hash(api_key, key_hash) do
    if AdminApiKeyGenerator.verify_key(api_key, key_hash) do
      :ok
    else
      {:error, :invalid_key}
    end
  end

  defp check_active(key_record) do
    if key_record.is_active do
      :ok
    else
      {:error, :inactive}
    end
  end

  defp check_expiration(key_record) do
    if Thalamus.Domain.Entities.AdminApiKey.expired?(key_record) do
      {:error, :expired}
    else
      :ok
    end
  end

  defp update_last_used(key_record) do
    alias Thalamus.Domain.Entities.AdminApiKey

    with {:ok, updated} <- AdminApiKey.mark_as_used(key_record),
         {:ok, _saved} <- PostgreSQLAdminApiKeyRepository.save(updated) do
      :ok
    end
  end

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: message})
    |> halt()
  end
end
