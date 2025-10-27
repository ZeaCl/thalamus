defmodule Thalamus.Application.Ports.AuditLogger do
  @moduledoc """
  Port (interface) for security audit logging.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for audit operations
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.ValueObjects.{UserId, OrganizationId, ClientId}

  @type event_type ::
          :authentication_success
          | :authentication_failure
          | :token_generated
          | :token_revoked
          | :mfa_enabled
          | :mfa_disabled
          | :password_changed
          | :organization_created
          | :member_added
          | :member_removed
          | :client_created
          | :client_secret_rotated

  @type context :: %{
          ip_address: String.t() | nil,
          user_agent: String.t() | nil,
          request_id: String.t() | nil,
          metadata: map()
        }

  @callback log_authentication_success(UserId.t(), context()) :: :ok
  @callback log_authentication_failure(String.t(), atom(), context()) :: :ok
  @callback log_token_generated(UserId.t(), ClientId.t(), context()) :: :ok
  @callback log_token_revoked(String.t(), context()) :: :ok
  @callback log_mfa_enabled(UserId.t(), atom(), context()) :: :ok
  @callback log_password_changed(UserId.t(), context()) :: :ok
  @callback log_organization_event(OrganizationId.t(), event_type(), context()) :: :ok
  @callback log_client_event(ClientId.t(), event_type(), context()) :: :ok
end
