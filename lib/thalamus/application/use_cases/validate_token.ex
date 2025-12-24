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
          valid: boolean(),
          active: boolean(),
          scope: [String.t()],
          client_id: String.t() | nil,
          user_id: String.t() | nil,
          organization_id: String.t() | nil,
          email: String.t() | nil,
          exp: DateTime.t() | nil,
          iat: DateTime.t() | nil
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
      valid: not token_data.revoked and not is_expired,
      active: not token_data.revoked and not is_expired,
      scope: token_data.scopes,
      client_id: to_string(token_data.client_id),
      user_id: if(token_data.user_id, do: to_string(token_data.user_id), else: nil),
      organization_id: if(token_data.organization_id, do: to_string(token_data.organization_id), else: nil),
      email: get_user_email(token_data),
      exp: token_data.expires_at,
      iat: token_data.created_at,
      revoked: token_data.revoked,
      expired: is_expired
    }
  end

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
      valid: false,
      active: false,
      scope: [],
      client_id: nil,
      user_id: nil,
      organization_id: nil,
      email: nil,
      exp: nil,
      iat: nil
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
