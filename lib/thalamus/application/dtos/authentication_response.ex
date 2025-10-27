defmodule Thalamus.Application.DTOs.AuthenticationResponse do
  @moduledoc """
  DTO for user authentication responses.

  SOLID Principles Applied:
  - Single Responsibility: Only carries authentication response data
  """

  alias Thalamus.Domain.Entities.User

  @type t :: %__MODULE__{
          user_id: String.t(),
          email: String.t(),
          mfa_required: boolean(),
          mfa_token: String.t() | nil,
          authenticated: boolean()
        }

  defstruct [:user_id, :email, :mfa_required, :mfa_token, :authenticated]

  @doc """
  Creates a successful authentication response.

  ## Examples

      iex> AuthenticationResponse.success(user)
      %AuthenticationResponse{authenticated: true, ...}
  """
  def success(%User{} = user) do
    %__MODULE__{
      user_id: user.id.value,
      email: user.email.value,
      mfa_required: User.mfa_enabled?(user),
      mfa_token: nil,
      authenticated: not User.mfa_enabled?(user)
    }
  end

  @doc """
  Creates an MFA required response with temporary token.

  ## Examples

      iex> AuthenticationResponse.mfa_required(user, "temp_token_123")
      %AuthenticationResponse{mfa_required: true, mfa_token: "temp_token_123", authenticated: false}
  """
  def mfa_required(%User{} = user, mfa_token) do
    %__MODULE__{
      user_id: user.id.value,
      email: user.email.value,
      mfa_required: true,
      mfa_token: mfa_token,
      authenticated: false
    }
  end
end
