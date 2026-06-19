defmodule ThalamusWeb.API.AgentTokenController do
  @moduledoc """
  Internal endpoint for Pi backend to generate short-lived agent tokens.
  Called without auth (internal_api pipeline).
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.PostgreSQLPersonalAccessTokenRepository
  alias Thalamus.Domain.Entities.PersonalAccessToken
  alias Thalamus.Domain.Services.PersonalAccessTokenGenerator
  alias Thalamus.Domain.ValueObjects.UserId
  alias Ecto.UUID

  @doc """
  POST /api/internal/agent-token
  Body: { "user_id": "...", "scopes": ["venture:read", ...] }
  Returns: { "token": "th_pat_live_...", "expires_at": "..." }
  """
  def create(conn, %{"user_id" => user_id} = params) do
    scopes = params["scopes"] || ["venture:read", "venture:write"]
    org_id = params["organization_id"] || "5fd11ea0-852c-44e5-aee1-a761ec76eaea"

    with {:ok, _uid} <- UserId.from_string(user_id) do
      env = Application.get_env(:thalamus, :environment, :prod)
      generated = PersonalAccessTokenGenerator.generate(env)
      id = UUID.generate()

      attrs = %{
        id: id,
        user_id: user_id,
        name: "agent-session-#{System.system_time(:second)}",
        token_hash: generated.token_hash,
        token_prefix: generated.token_prefix,
        scopes: scopes,
        is_active: true,
        organization_id: org_id,
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      case PersonalAccessToken.new(attrs) do
        {:ok, pat} ->
          case PostgreSQLPersonalAccessTokenRepository.save(pat) do
            {:ok, _saved} ->
              conn
              |> put_status(:created)
              |> json(%{
                token: generated.token,
                scopes: scopes,
                expires_in: 3600
              })

            {:error, reason} ->
              conn
              |> put_status(500)
              |> json(%{error: "Failed to save token", details: inspect(reason)})
          end

        {:error, reason} ->
          conn
          |> put_status(400)
          |> json(%{error: "Invalid token attrs", details: inspect(reason)})
      end
    else
      {:error, _} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid user_id"})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing user_id"})
  end
end
