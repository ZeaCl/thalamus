defmodule ThalamusWeb.API.PersonalAccessTokenController do
  @moduledoc """
  API Controller for managing Personal Access Tokens (PATs).
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.PostgreSQLPersonalAccessTokenRepository
  alias Thalamus.Domain.Entities.PersonalAccessToken
  alias Thalamus.Domain.Services.PersonalAccessTokenGenerator

  @doc """
  GET /api/personal-access-tokens

  List all active Personal Access Tokens for the authenticated user.
  """
  def index(conn, _params) do
    user_id = get_user_id(conn)

    case PostgreSQLPersonalAccessTokenRepository.list_for_user(user_id) do
      {:ok, pats} ->
        conn
        |> put_status(:ok)
        |> json(%{data: Enum.map(pats, &pat_to_json/1)})
    end
  end

  @doc """
  POST /api/personal-access-tokens

  Create a new Personal Access Token.
  """
  def create(conn, %{"name" => name, "organization_id" => organization_id} = params) do
    user_id = get_user_id(conn)
    scopes = params["scopes"] || ["openid", "profile", "email", "zea:read", "zea:write"]
    org_id = organization_id || get_org_id(conn) || get_first_org_id(conn, user_id)

    generated = PersonalAccessTokenGenerator.generate()
    id = Ecto.UUID.generate()

    attrs = %{
      id: id,
      token_hash: generated.token_hash,
      token_prefix: generated.token_prefix,
      name: name,
      scopes: scopes,
      is_active: true,
      user_id: user_id,
      organization_id: org_id
    }

    with {:ok, pat} <- PersonalAccessToken.new(attrs),
         {:ok, saved_pat} <- PostgreSQLPersonalAccessTokenRepository.save(pat) do
      conn
      |> put_status(:created)
      |> json(%{
        data: pat_to_json(saved_pat),
        # Only returned once upon creation!
        token: generated.token,
        message:
          "Personal Access Token created successfully. Please copy it now as it won't be shown again."
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to create token", details: inspect(reason)})
    end
  end

  # Fallback clause when organization_id is not in params
  def create(conn, %{"name" => _} = params) do
    create(conn, Map.put(params, "organization_id", nil))
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "name is required"})
  end

  @doc """
  DELETE /api/personal-access-tokens/:id

  Revoke a Personal Access Token.
  """
  def delete(conn, %{"id" => id}) do
    user_id = get_user_id(conn)

    case PostgreSQLPersonalAccessTokenRepository.find_by_id(id) do
      {:ok, pat} ->
        # Ensure owner is the one deleting
        if pat.user_id == user_id do
          case PostgreSQLPersonalAccessTokenRepository.delete(id) do
            :ok ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Token revoked successfully"})

            {:error, _} ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{error: "Failed to revoke token"})
          end
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "You are not authorized to revoke this token"})
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Token not found"})
    end
  end

  # Helpers

  defp get_user_id(conn) do
    # Handle different auth assigns formats from AuthenticateToken and APIAuth
    user_id = conn.assigns[:current_user_id] || conn.assigns[:user_id]
    if is_struct(user_id), do: to_string(user_id), else: user_id
  end

  defp get_org_id(conn) do
    auth = conn.assigns[:auth_context]
    if is_map(auth), do: auth[:organization_id], else: nil
  end

  defp get_first_org_id(_conn, nil), do: nil

  defp get_first_org_id(_conn, user_id) when is_binary(user_id) do
    import Ecto.Query
    alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema
    alias Thalamus.Repo

    case Ecto.UUID.cast(user_id) do
      {:ok, uuid} ->
        Repo.one(from u in UserSchema, where: u.id == ^uuid, select: u.organization_id)

      _ ->
        nil
    end
  end

  # Fallback clause when organization_id is not in params at all
  defp pat_to_json(%PersonalAccessToken{} = pat) do
    %{
      id: pat.id,
      name: pat.name,
      token_prefix: pat.token_prefix,
      scopes: pat.scopes,
      is_active: pat.is_active,
      expires_at: pat.expires_at,
      last_used_at: pat.last_used_at,
      user_id: pat.user_id,
      organization_id: pat.organization_id,
      created_at: pat.created_at
    }
  end
end
