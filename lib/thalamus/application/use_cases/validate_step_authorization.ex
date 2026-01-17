defmodule Thalamus.Application.UseCases.ValidateStepAuthorization do
  @moduledoc """
  Validates if an agent token has authorization to execute a specific workflow step.

  This use case is called by Cerebelum (workflow engine) **before** executing each step
  in a workflow to ensure the agent has the required scopes.

  ## Validations Performed

  1. **Token Exists**: Token can be found by access_token string
  2. **Not Expired**: Current time < token.expires_at
  3. **Not Revoked**: token.status == :active
  4. **Has Required Scopes**: requested_scopes ⊆ token.scopes
  5. **Organization Match**: (optional) workflow org == token org

  ## Audit Logging

  Every authorization check is logged for compliance and security auditing:
  - Granted authorizations (info level)
  - Denied authorizations (warning level)
  - Includes step name, required scopes, and decision reason

  ## SOLID Principles

  - **Single Responsibility**: Only validates authorization, doesn't execute steps
  - **Open/Closed**: Extensible via additional validation functions
  - **Dependency Inversion**: Depends on AgentTokenRepository port

  ## Usage

      # From Cerebelum workflow engine
      deps = DependencyBuilder.build_for_cerebelum()

      result = ValidateStepAuthorization.execute(
        %{
          token: "at_abc123...",
          step_name: "send_email",
          required_scopes: ["email:send", "email:read"],
          workflow_context: %{workflow_id: "wf_123"}
        },
        deps
      )

      case result do
        {:ok, %{authorized: true}} -> execute_step()
        {:error, :insufficient_scopes} -> deny_step()
      end

  ## Response

      {:ok, %{
        authorized: true,
        agent_id: "agt_abc123",
        agent_type: "autonomous",
        scopes: ["email:send", "email:read", "calendar:read"]
      }}

  ## Errors

  - `{:error, :token_not_found}` - Token doesn't exist
  - `{:error, :token_expired}` - Token has expired
  - `{:error, :token_revoked}` - Token has been revoked
  - `{:error, :insufficient_scopes}` - Token lacks required scopes
  - `{:error, :invalid_token_format}` - Token string format invalid
  """

  require Logger

  @type request :: %{
          required(:token) => String.t(),
          required(:step_name) => String.t(),
          required(:required_scopes) => [String.t()],
          optional(:workflow_context) => map()
        }

  @type response :: %{
          authorized: boolean(),
          agent_id: binary(),
          agent_type: String.t(),
          scopes: [String.t()]
        }

  @type deps :: %{
          required(:agent_token_repository) => module(),
          required(:audit_logger) => module()
        }

  @doc """
  Executes the authorization validation for a workflow step.

  ## Parameters

  - `request` - Map with token, step_name, required_scopes, and optional workflow_context
  - `deps` - Dependency map with agent_token_repository and audit_logger

  ## Returns

  - `{:ok, response}` - Authorization granted
  - `{:error, reason}` - Authorization denied
  """
  @spec execute(request(), deps()) :: {:ok, response()} | {:error, atom()}
  def execute(
        %{token: token, step_name: step_name, required_scopes: scopes} = request,
        %{agent_token_repository: _, audit_logger: _} = deps
      ) do
    with {:ok, agent_token} <- find_and_validate_token(token, deps),
         :ok <- validate_not_expired(agent_token),
         :ok <- validate_not_revoked(agent_token),
         :ok <- validate_has_scopes(agent_token, scopes),
         :ok <- validate_workflow_context(agent_token, request),
         :ok <- log_authorization_check(agent_token, step_name, :granted, scopes, deps) do
      {:ok,
       %{
         authorized: true,
         agent_id: agent_token.id,
         agent_type: to_string(agent_token.agent_type),
         scopes: agent_token.scopes
       }}
    else
      {:error, reason} = error ->
        log_authorization_check(token, step_name, {:denied, reason}, scopes, deps)
        error
    end
  end

  # Validate request has required fields
  def execute(%{token: _}, _deps) do
    {:error, :missing_required_fields}
  end

  def execute(_request, _deps) do
    {:error, :invalid_request}
  end

  # Private Functions

  @spec find_and_validate_token(String.t(), deps()) ::
          {:ok, Thalamus.Domain.Entities.AgentToken.t()} | {:error, atom()}
  defp find_and_validate_token(token, %{agent_token_repository: repo}) when is_binary(token) do
    # Validate token format (should start with "at_")
    if String.starts_with?(token, "at_") do
      case repo.find_by_access_token(token) do
        {:ok, agent_token} -> {:ok, agent_token}
        {:error, :not_found} -> {:error, :token_not_found}
        error -> error
      end
    else
      {:error, :invalid_token_format}
    end
  end

  defp find_and_validate_token(_token, _deps) do
    {:error, :invalid_token_format}
  end

  @spec validate_not_expired(Thalamus.Domain.Entities.AgentToken.t()) :: :ok | {:error, atom()}
  defp validate_not_expired(agent_token) do
    case DateTime.compare(agent_token.expires_at, DateTime.utc_now()) do
      :gt ->
        :ok

      _ ->
        {:error, :token_expired}
    end
  end

  @spec validate_not_revoked(Thalamus.Domain.Entities.AgentToken.t()) :: :ok | {:error, atom()}
  defp validate_not_revoked(agent_token) do
    if agent_token.status == :active do
      :ok
    else
      {:error, :token_revoked}
    end
  end

  @spec validate_has_scopes(Thalamus.Domain.Entities.AgentToken.t(), [String.t()]) ::
          :ok | {:error, atom()}
  defp validate_has_scopes(agent_token, required_scopes) do
    token_scopes = MapSet.new(agent_token.scopes)
    required_set = MapSet.new(required_scopes)

    if MapSet.subset?(required_set, token_scopes) do
      :ok
    else
      missing_scopes = MapSet.difference(required_set, token_scopes) |> MapSet.to_list()

      Logger.warning(
        "Token missing required scopes. Token: #{agent_token.id}, Missing: #{inspect(missing_scopes)}"
      )

      {:error, :insufficient_scopes}
    end
  end

  @spec validate_workflow_context(Thalamus.Domain.Entities.AgentToken.t(), request()) ::
          :ok | {:error, atom()}
  defp validate_workflow_context(_agent_token, %{workflow_context: context})
       when is_map(context) do
    # Optional: Future validation of workflow_id, organization_id, etc.
    # For now, we just accept any context
    :ok
  end

  defp validate_workflow_context(_agent_token, _request) do
    # No workflow context provided, that's OK
    :ok
  end

  @spec log_authorization_check(
          String.t() | Thalamus.Domain.Entities.AgentToken.t(),
          String.t(),
          :granted | {:denied, atom()},
          [String.t()],
          deps()
        ) :: :ok
  defp log_authorization_check(
         %{id: agent_id, agent_type: agent_type, organization_id: org_id} = _agent_token,
         step_name,
         :granted,
         required_scopes,
         %{audit_logger: logger}
       ) do
    logger.log(%{
      event_type: "step_authorization.granted",
      actor_type: "agent_token",
      actor_id: agent_id,
      organization_id: org_id,
      resource_type: "workflow_step",
      resource_id: step_name,
      timestamp: DateTime.utc_now(),
      metadata: %{
        agent_type: to_string(agent_type),
        step_name: step_name,
        required_scopes: required_scopes,
        decision: "granted"
      }
    })

    :ok
  end

  defp log_authorization_check(
         token,
         step_name,
         {:denied, reason},
         required_scopes,
         %{audit_logger: logger}
       ) do
    # Token might be invalid, so we log with minimal info
    logger.log(%{
      event_type: "step_authorization.denied",
      actor_type: "unknown",
      actor_id: extract_token_id(token),
      organization_id: nil,
      resource_type: "workflow_step",
      resource_id: step_name,
      timestamp: DateTime.utc_now(),
      metadata: %{
        step_name: step_name,
        required_scopes: required_scopes,
        decision: "denied",
        reason: to_string(reason)
      }
    })

    :ok
  end

  @spec extract_token_id(String.t() | Thalamus.Domain.Entities.AgentToken.t()) :: String.t()
  defp extract_token_id(%{id: id}), do: id
  defp extract_token_id(token) when is_binary(token), do: "masked:#{String.slice(token, 0..10)}"
  defp extract_token_id(_), do: "unknown"
end
