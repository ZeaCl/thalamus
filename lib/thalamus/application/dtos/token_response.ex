defmodule Thalamus.Application.DTOs.TokenResponse do
  @moduledoc """
  DTO for OAuth2 token responses.

  SOLID Principles Applied:
  - Single Responsibility: Only carries token response data
  """

  @type t :: %__MODULE__{
          access_token: String.t(),
          token_type: String.t(),
          expires_in: pos_integer(),
          refresh_token: String.t() | nil,
          scope: String.t() | nil,
          id_token: String.t() | nil
        }

  defstruct [:access_token, :token_type, :expires_in, :refresh_token, :scope, :id_token]

  @doc """
  Creates a successful token response.

  ## Examples

      iex> TokenResponse.success(
      ...>   "access_token_123",
      ...>   3600,
      ...>   "refresh_token_456",
      ...>   "openid profile"
      ...> )
      %TokenResponse{access_token: "access_token_123", ...}
  """
  def success(access_token, expires_in, refresh_token \\ nil, scope \\ nil, id_token \\ nil) do
    %__MODULE__{
      access_token: access_token,
      token_type: "Bearer",
      expires_in: expires_in,
      refresh_token: refresh_token,
      scope: scope,
      id_token: id_token
    }
  end

  @doc """
  Converts the response to a map for JSON encoding.

  ## Examples

      iex> response = TokenResponse.success("token", 3600)
      iex> TokenResponse.to_map(response)
      %{access_token: "token", token_type: "Bearer", expires_in: 3600}
  """
  def to_map(%__MODULE__{} = response) do
    response
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
