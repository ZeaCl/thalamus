defmodule Thalamus.Application.DTOs.AuthenticationResponse do
  @moduledoc """
  DTO for user authentication responses.

  Carries user profile fields so callers can build JWTs or render user
  data without a second DB query.

  SOLID Principles Applied:
  - Single Responsibility: Only carries authentication response data
  """

  alias Thalamus.Domain.Entities.User

  @type t :: %__MODULE__{
          user_id: String.t(),
          email: String.t(),
          name: String.t() | nil,
          organization_id: String.t() | nil,
          is_agent: boolean(),
          email_verified: boolean(),
          mfa_required: boolean(),
          mfa_token: String.t() | nil,
          authenticated: boolean()
        }

  defstruct [
    :user_id,
    :email,
    :name,
    :organization_id,
    :is_agent,
    :email_verified,
    :mfa_required,
    :mfa_token,
    :authenticated
  ]

  @doc """
  Creates a successful authentication response.

  Carries user profile fields (name, organization_id, is_agent, email_verified)
  so callers can build JWTs without a second DB query.

  ## Examples

      iex> AuthenticationResponse.success(user)
      %AuthenticationResponse{authenticated: true, ...}
  """
  def success(%User{} = user) do
    %__MODULE__{
      user_id: user.id.value,
      email: user.email.value,
      name: user.name,
      organization_id: user.organization_id,
      is_agent: user.is_agent,
      email_verified: user.email_verified,
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
      name: user.name,
      organization_id: user.organization_id,
      is_agent: user.is_agent,
      email_verified: user.email_verified,
      mfa_required: true,
      mfa_token: mfa_token,
      authenticated: false
    }
  end
end
