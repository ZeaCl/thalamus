defmodule ThalamusWeb.API.InternalAgentConfigController do
  @moduledoc """
  Internal endpoint for microservices (Pi backend, Glia, etc.) to look up
  agent configuration without requiring JWT authentication.

  Runs under the `internal_api` pipeline — no auth required for intra-network calls.
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository
  alias Thalamus.Domain.ValueObjects.UserId

  @doc """
  GET /api/internal/users/:id/agent-config

  Returns the agent config for a user if they are an agent.
  Returns 404 if user not found or not an agent.

  ## Response (200)
  {
    "data": {
      "id": "user_abc123",
      "is_agent": true,
      "agent_config": {
        "skills": ["gestion-fondos", "dominio-fondos"],
        "system_prompt": "Eres un asistente...",
        "model": "deepseek/deepseek-chat"
      }
    }
  }
  """
  def show(conn, %{"id" => id}) do
    with {:ok, user_id} <- UserId.from_string(id),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id) do
      if user.is_agent do
        conn
        |> put_status(:ok)
        |> json(%{
          data: %{
            id: user.id,
            is_agent: true,
            agent_config: user.agent_config || %{}
          }
        })
      else
        conn
        |> put_status(:not_found)
        |> json(%{error: "User is not an agent"})
      end
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid user ID format"})
    end
  end
end
