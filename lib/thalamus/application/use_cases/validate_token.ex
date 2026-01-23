defmodule Thalamus.Application.UseCases.ValidateToken do
  @moduledoc """
  Use Case for validating OAuth2 access tokens.

  SOLID Principles Applied:
  - Single Responsibility: Only handles token validation
  - Dependency Inversion: Depends on ports (interfaces)
  """

  # Ports are referenced via deps parameter

  @type deps :: %{
          token_repository: module()
        }

  @type validation_result :: %{
          # Standard OAuth2 fields
          valid: boolean(),
          active: boolean(),
          scope: [String.t()],
          client_id: String.t() | nil,
          user_id: String.t() | nil,
          organization_id: String.t() | nil,
          email: String.t() | nil,
          exp: DateTime.t() | nil,
          iat: DateTime.t() | nil,

          # Agent-specific fields (optional)
          agent_type: String.t() | nil,
          delegated_by: String.t() | nil,
          delegation_chain: [String.t()],
          delegation_depth: non_neg_integer(),
          task_id: String.t() | nil,
          task_type: String.t() | nil,
          task_scopes: [String.t()],
          max_operations: non_neg_integer() | nil,
          operations_remaining: non_neg_integer() | nil,
          expires_on_completion: boolean(),
          intent_description: String.t() | nil,
          orchestrator_id: String.t() | nil,
          environment: String.t() | nil
        }

  @doc """
  Validates an access token.

  Returns detailed information about the token including:
  - Whether it's valid and active
  - Associated scopes
  - Client and user IDs
  - Expiration and issued times

  ## Examples

      iex> ValidateToken.execute("at_abc123...", deps)
      {:ok, %{valid: true, active: true, scope: ["openid"], ...}}

      iex> ValidateToken.execute("invalid_token", deps)
      {:ok, %{valid: false, active: false}}
  """
  def execute(token, deps) when is_binary(token) do
    case find_token(token, deps) do
      {:ok, token_data} ->
        result = validate_token_data(token_data)
        {:ok, result}

      {:error, :not_found} ->
        {:ok, invalid_token_result()}
    end
  end

  def execute(_, _), do: {:error, :invalid_token_format}

  @doc """
  Validates a token for a specific scope.

  ## Examples

      iex> ValidateToken.execute_with_scope("at_abc123...", "openid profile", deps)
      {:ok, %{valid: true, has_required_scope: true, ...}}
  """
  def execute_with_scope(token, required_scope, deps)
      when is_binary(token) and is_binary(required_scope) do
    with {:ok, result} <- execute(token, deps) do
      required_scopes = parse_scopes(required_scope)
      has_scope = has_required_scopes?(result.scope, required_scopes)

      {:ok, Map.put(result, :has_required_scope, has_scope)}
    end
  end

  # Private functions

  defp find_token(token, %{token_repository: repo}) do
    repo.find(token)
  end

  defp validate_token_data(token_data) do
    now = DateTime.utc_now()
    is_expired = DateTime.compare(now, token_data.expires_at) == :gt

    %{
      # Standard OAuth2 fields
      valid: not token_data.revoked and not is_expired,
      active: not token_data.revoked and not is_expired,
      scope: token_data.scopes || [],
      client_id: to_string(token_data.client_id),
      user_id: if(token_data.user_id, do: to_string(token_data.user_id), else: nil),
      organization_id:
        if(token_data.organization_id, do: to_string(token_data.organization_id), else: nil),
      email: get_user_email(token_data),
      exp: token_data.expires_at,
      iat: token_data.created_at,
      revoked: token_data.revoked,
      expired: is_expired,

      # Agent-specific fields
      agent_type: Map.get(token_data, :agent_type),
      delegated_by: format_user_id(Map.get(token_data, :delegated_by_user_id)),
      delegation_chain: format_delegation_chain(Map.get(token_data, :delegation_chain, [])),
      delegation_depth: length(Map.get(token_data, :delegation_chain, [])),
      task_id: Map.get(token_data, :task_id),
      task_type: Map.get(token_data, :task_type),
      task_scopes: Map.get(token_data, :task_scopes, []),
      max_operations: Map.get(token_data, :max_operations),
      operations_remaining: calculate_operations_remaining(token_data),
      expires_on_completion: Map.get(token_data, :expires_on_completion, false),
      intent_description: Map.get(token_data, :intent_description),
      orchestrator_id: Map.get(token_data, :orchestrator_id),
      environment: Map.get(token_data, :environment)
    }
  end

  defp format_user_id(nil), do: nil
  defp format_user_id(user_id) when is_binary(user_id), do: user_id
  defp format_user_id(user_id), do: to_string(user_id)

  defp format_delegation_chain(nil), do: []

  defp format_delegation_chain(chain) when is_list(chain) do
    Enum.map(chain, fn
      id when is_binary(id) -> id
      id -> to_string(id)
    end)
  end

  defp format_delegation_chain(_), do: []

  defp calculate_operations_remaining(%{max_operations: nil}), do: nil

  defp calculate_operations_remaining(%{max_operations: max, operations_count: count}) do
    remaining = max - count
    if remaining < 0, do: 0, else: remaining
  end

  defp calculate_operations_remaining(_), do: nil

  defp get_user_email(%{user_id: nil}), do: nil

  defp get_user_email(%{user_id: user_id}) when not is_nil(user_id) do
    # We need to fetch the user to get their email
    # This requires accessing the user repository
    # For now, we'll return nil and handle this in the controller
    # TODO: Inject user_repository dependency
    nil
  end

  defp invalid_token_result do
    %{
      # Standard OAuth2 fields
      valid: false,
      active: false,
      scope: [],
      client_id: nil,
      user_id: nil,
      organization_id: nil,
      email: nil,
      exp: nil,
      iat: nil,
      revoked: false,
      expired: false,

      # Agent-specific fields (all nil for invalid tokens)
      agent_type: nil,
      delegated_by: nil,
      delegation_chain: [],
      delegation_depth: 0,
      task_id: nil,
      task_type: nil,
      task_scopes: [],
      max_operations: nil,
      operations_remaining: nil,
      expires_on_completion: false,
      intent_description: nil,
      orchestrator_id: nil,
      environment: nil
    }
  end

  defp parse_scopes(scope_string) when is_binary(scope_string) do
    scope_string
    |> String.split(" ")
    |> Enum.reject(&(&1 == ""))
  end

  defp has_required_scopes?(token_scopes, required_scopes) do
    Enum.all?(required_scopes, fn scope -> scope in token_scopes end)
  end
end
