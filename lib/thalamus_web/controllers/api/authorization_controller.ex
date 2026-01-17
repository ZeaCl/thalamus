defmodule ThalamusWeb.API.AuthorizationController do
  @moduledoc """
  HTTP API for workflow step authorization validation.

  This controller exposes HTTP endpoints that Cerebelum (or other external services)
  can call to validate agent token authorization before executing workflow steps.

  ## Endpoints

  - `POST /api/authorization/validate-step` - Validate step authorization

  ## Authentication

  Requests must include a Bearer token in the Authorization header:

      Authorization: Bearer at_abc123...

  ## Rate Limiting

  - 1000 requests/minute per token
  - 429 Too Many Requests if limit exceeded

  ## Example Request

      POST /api/authorization/validate-step
      Authorization: Bearer at_abc123...
      Content-Type: application/json

      {
        "step_name": "send_email",
        "required_scopes": ["email:send", "email:read"],
        "context": {
          "workflow_id": "wf_send_weekly_report",
          "execution_id": "exec_123"
        }
      }

  ## Example Response (200 OK)

      {
        "authorized": true,
        "agent_id": "agt_xyz789",
        "agent_type": "autonomous",
        "scopes": ["email:send", "email:read", "calendar:read"]
      }

  ## Error Responses

  - `401 Unauthorized` - Missing or invalid token
  - `403 Forbidden` - Token lacks required scopes
  - `422 Unprocessable Entity` - Invalid request parameters
  - `429 Too Many Requests` - Rate limit exceeded
  - `500 Internal Server Error` - Server error
  """

  use ThalamusWeb, :controller

  require Logger

  @doc """
  Validates if the bearer token can execute a workflow step.

  ## Request Body

  - `step_name` (required) - Workflow step identifier
  - `required_scopes` (required) - Array of scope strings
  - `context` (optional) - Workflow context metadata

  ## Success Response (200)

      {
        "authorized": true,
        "agent_id": "agt_xyz789",
        "agent_type": "autonomous",
        "scopes": ["email:send", "email:read"]
      }

  ## Error Responses

  - `401` - Token expired, revoked, or invalid
  - `403` - Token lacks required scopes
  - `422` - Invalid request parameters
  """
  def validate_step(conn, params) do
    with {:ok, token} <- extract_bearer_token(conn),
         {:ok, step_name} <- get_required_param(params, "step_name"),
         {:ok, required_scopes} <- get_required_scopes(params),
         context <- get_optional_context(params),
         {:ok, result} <- Thalamus.API.validate_step(token, step_name, required_scopes, context) do
      json(conn, result)
    else
      {:error, :missing_authorization_header} ->
        conn
        |> put_status(401)
        |> json(%{
          error: "unauthorized",
          message: "Missing Authorization header"
        })

      {:error, :invalid_token_format} ->
        conn
        |> put_status(401)
        |> json(%{
          error: "unauthorized",
          message: "Invalid token format. Expected: Bearer at_..."
        })

      {:error, :token_not_found} ->
        conn
        |> put_status(401)
        |> json(%{
          error: "unauthorized",
          message: "Token not found or invalid"
        })

      {:error, :token_expired} ->
        conn
        |> put_status(401)
        |> json(%{
          error: "token_expired",
          message: "Agent token has expired"
        })

      {:error, :token_revoked} ->
        conn
        |> put_status(401)
        |> json(%{
          error: "token_revoked",
          message: "Agent token has been revoked"
        })

      {:error, :insufficient_scopes} ->
        conn
        |> put_status(403)
        |> json(%{
          error: "insufficient_scopes",
          message: "Token lacks required scopes for this operation"
        })

      {:error, :missing_step_name} ->
        conn
        |> put_status(422)
        |> json(%{
          error: "invalid_request",
          message: "Missing required parameter: step_name"
        })

      {:error, :missing_required_scopes} ->
        conn
        |> put_status(422)
        |> json(%{
          error: "invalid_request",
          message: "Missing required parameter: required_scopes"
        })

      {:error, :invalid_required_scopes} ->
        conn
        |> put_status(422)
        |> json(%{
          error: "invalid_request",
          message: "Parameter required_scopes must be an array of strings"
        })

      {:error, reason} ->
        Logger.error("Unexpected error in validate_step: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{
          error: "internal_server_error",
          message: "An unexpected error occurred"
        })
    end
  end

  # Private Functions

  @spec extract_bearer_token(Plug.Conn.t()) :: {:ok, String.t()} | {:error, atom()}
  defp extract_bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        {:ok, token}

      ["bearer " <> token] ->
        # Case-insensitive
        {:ok, token}

      [_other] ->
        {:error, :invalid_token_format}

      [] ->
        {:error, :missing_authorization_header}
    end
  end

  @spec get_required_param(map(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  defp get_required_param(params, key) do
    case Map.get(params, key) do
      nil -> {:error, String.to_atom("missing_#{key}")}
      value when is_binary(value) -> {:ok, value}
      _other -> {:error, String.to_atom("invalid_#{key}")}
    end
  end

  @spec get_required_scopes(map()) :: {:ok, [String.t()]} | {:error, atom()}
  defp get_required_scopes(params) do
    case Map.get(params, "required_scopes") do
      nil ->
        {:error, :missing_required_scopes}

      scopes when is_list(scopes) ->
        if Enum.all?(scopes, &is_binary/1) do
          {:ok, scopes}
        else
          {:error, :invalid_required_scopes}
        end

      _other ->
        {:error, :invalid_required_scopes}
    end
  end

  @spec get_optional_context(map()) :: map()
  defp get_optional_context(params) do
    case Map.get(params, "context") do
      context when is_map(context) -> context
      _other -> %{}
    end
  end
end
