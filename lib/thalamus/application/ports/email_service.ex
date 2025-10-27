defmodule Thalamus.Application.Ports.EmailService do
  @moduledoc """
  Port (interface) for email delivery.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for email operations
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.ValueObjects.Email

  @type email_data :: %{
          to: Email.t(),
          subject: String.t(),
          body: String.t(),
          template: atom() | nil,
          variables: map()
        }

  @callback send_verification_email(Email.t(), String.t()) :: :ok | {:error, term()}
  @callback send_password_reset_email(Email.t(), String.t()) :: :ok | {:error, term()}
  @callback send_mfa_code_email(Email.t(), String.t()) :: :ok | {:error, term()}
  @callback send_welcome_email(Email.t(), String.t()) :: :ok | {:error, term()}
  @callback send_custom_email(email_data()) :: :ok | {:error, term()}
end
