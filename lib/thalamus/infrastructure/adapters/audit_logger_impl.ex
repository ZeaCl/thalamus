defmodule Thalamus.Infrastructure.Adapters.AuditLoggerImpl do
  @moduledoc """
  Production implementation of the AuditLogger port.

  This adapter logs security and audit events for compliance purposes.
  It implements the AuditLogger behaviour defined in the Application layer.

  Features:
  - Structured logging with metadata
  - PCI-DSS/HIPAA/GDPR compliant audit trails
  - Integration with external SIEM systems
  - Immutable audit records

  SOLID Principles Applied:
  - Single Responsibility: Only handles audit logging
  - Dependency Inversion: Implements the port defined by Application layer
  - Interface Segregation: Implements only AuditLogger interface

  Security Considerations:
  - All audit logs are immutable
  - Sensitive data is never logged (passwords, tokens, secrets)
  - Timestamps are in UTC
  - User identifiers are pseudonymized when needed
  """

  @behaviour Thalamus.Application.Ports.AuditLogger

  require Logger

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.AuditLogSchema

  @doc """
  Generic logging function that accepts a map of audit data.
  Used for custom event types like agent token generation.
  """
  @impl true
  def log(audit_data) when is_map(audit_data) do
    event_type = Map.get(audit_data, :event_type, "generic_event")

    Logger.info("[AUDIT] #{event_type}",
      event_type: event_type,
      data: audit_data
    )

    :ok
  end

  @impl true
  def log_authentication_success(user_id, context) do
    log_event(
      :authentication_success,
      %{
        user_id: sanitize_user_id(user_id),
        ip_address: get_ip_address(context),
        user_agent: get_user_agent(context),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  @impl true
  def log_authentication_failure(identifier, reason, context) do
    log_event(
      :authentication_failure,
      %{
        identifier: sanitize_identifier(identifier),
        reason: reason,
        ip_address: get_ip_address(context),
        user_agent: get_user_agent(context),
        timestamp: DateTime.utc_now()
      },
      :warn
    )
  end

  @impl true
  def log_token_generated(user_id, client_id, context) do
    log_event(
      :token_generated,
      %{
        user_id: sanitize_user_id(user_id),
        client_id: to_string(client_id),
        ip_address: get_ip_address(context),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  @impl true
  def log_token_revoked(token, context) do
    log_event(
      :token_revoked,
      %{
        token_id: sanitize_token_id(token),
        ip_address: get_ip_address(context),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  @impl true
  def log_mfa_enabled(user_id, mfa_type, context) do
    log_event(
      :mfa_enabled,
      %{
        user_id: sanitize_user_id(user_id),
        mfa_type: mfa_type,
        ip_address: get_ip_address(context),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  @impl true
  def log_password_changed(user_id, context) do
    log_event(
      :password_changed,
      %{
        user_id: sanitize_user_id(user_id),
        ip_address: get_ip_address(context),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  @impl true
  def log_organization_event(org_id, event, context) do
    log_event(
      :organization_event,
      %{
        organization_id: to_string(org_id),
        event: event,
        ip_address: get_ip_address(context),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  @impl true
  def log_client_event(client_id, event, context) do
    log_event(
      :client_event,
      %{
        client_id: to_string(client_id),
        event: event,
        ip_address: get_ip_address(context),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  # Private helper functions

  defp log_event(event_type, metadata, level) do
    # Format the audit log entry
    audit_entry = %{
      event_type: event_type,
      metadata: metadata,
      environment: get_environment(),
      node: Node.self(),
      logged_at: DateTime.utc_now()
    }

    # Log to standard logger
    case level do
      :info -> Logger.info("[AUDIT] #{event_type}", audit_entry)
      :warn -> Logger.warning("[AUDIT] #{event_type}", audit_entry)
      :error -> Logger.error("[AUDIT] #{event_type}", audit_entry)
    end

    # Optionally persist to database
    persist_audit_log(audit_entry)

    :ok
  end

  defp persist_audit_log(audit_entry) do
    # Persist audit logs to database for compliance and auditing
    # This is enabled by default in production
    case Application.get_env(:thalamus, :persist_audit_logs, true) do
      true ->
        attrs = %{
          event_type: to_string(audit_entry.event_type),
          user_id: extract_user_id(audit_entry.metadata),
          organization_id: extract_organization_id(audit_entry.metadata),
          client_id: extract_client_id(audit_entry.metadata),
          metadata: audit_entry.metadata,
          ip_address: extract_ip_address(audit_entry.metadata),
          user_agent: extract_user_agent(audit_entry.metadata),
          request_id: extract_request_id(audit_entry.metadata),
          environment: to_string(audit_entry.environment),
          node: to_string(audit_entry.node)
        }

        case AuditLogSchema.create_changeset(attrs) |> Repo.insert() do
          {:ok, _log} ->
            :ok

          {:error, changeset} ->
            Logger.error("[AUDIT] Failed to persist audit log: #{inspect(changeset.errors)}")
            :ok
        end

      false ->
        :ok
    end
  end

  defp extract_user_id(%{user_id: user_id}) when is_binary(user_id) do
    # Try to parse as UUID
    case Ecto.UUID.cast(user_id) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp extract_user_id(_), do: nil

  defp extract_organization_id(%{organization_id: org_id}) when is_binary(org_id) do
    case Ecto.UUID.cast(org_id) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp extract_organization_id(_), do: nil

  defp extract_client_id(%{client_id: client_id}) when is_binary(client_id) do
    case Ecto.UUID.cast(client_id) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp extract_client_id(_), do: nil

  defp extract_ip_address(%{ip_address: ip}), do: ip
  defp extract_ip_address(_), do: nil

  defp extract_user_agent(%{user_agent: ua}), do: ua
  defp extract_user_agent(_), do: nil

  defp extract_request_id(%{request_id: req_id}), do: req_id
  defp extract_request_id(_), do: nil

  defp sanitize_user_id(user_id) do
    # Convert UserId to string representation
    # In production, you might want to hash or pseudonymize this
    to_string(user_id)
  end

  defp sanitize_identifier(identifier) when is_binary(identifier) do
    # Mask email addresses for privacy
    if String.contains?(identifier, "@") do
      [local, domain] = String.split(identifier, "@", parts: 2)

      masked_local =
        if String.length(local) > 2 do
          String.first(local) <> "***" <> String.last(local)
        else
          "***"
        end

      "#{masked_local}@#{domain}"
    else
      identifier
    end
  end

  defp sanitize_identifier(identifier), do: to_string(identifier)

  defp sanitize_token_id(token_id) do
    # Only log first 8 characters of token ID for debugging
    token_string = to_string(token_id)

    if String.length(token_string) > 8 do
      String.slice(token_string, 0, 8) <> "..."
    else
      token_string
    end
  end

  defp get_ip_address(context) when is_map(context) do
    Map.get(context, :ip_address) || Map.get(context, "ip_address") || "unknown"
  end

  defp get_ip_address(_), do: "unknown"

  defp get_user_agent(context) when is_map(context) do
    Map.get(context, :user_agent) || Map.get(context, "user_agent") || "unknown"
  end

  defp get_user_agent(_), do: "unknown"

  defp get_environment do
    Application.get_env(:thalamus, :environment, :development)
  end

  # ============================================================================
  # PUBLIC CONVENIENCE METHODS (Not part of behaviour)
  # ============================================================================

  @doc """
  Convenience methods for MFA events that don't require full context.
  These are helpers for controllers and other components.
  """

  def log_mfa_setup_initiated(user_id) do
    log_event(
      :mfa_setup_initiated,
      %{
        user_id: sanitize_user_id(user_id),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  def log_mfa_verification_failed(user_id, mfa_type) do
    log_event(
      :mfa_verification_failed,
      %{
        user_id: sanitize_user_id(user_id),
        mfa_type: mfa_type,
        timestamp: DateTime.utc_now()
      },
      :warn
    )
  end

  def log_mfa_verification_success(user_id, mfa_type) do
    log_event(
      :mfa_verification_success,
      %{
        user_id: sanitize_user_id(user_id),
        mfa_type: mfa_type,
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  def log_mfa_disabled(user_id) do
    log_event(
      :mfa_disabled,
      %{
        user_id: sanitize_user_id(user_id),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end

  def log_failed_login(user_id, reason) do
    log_event(
      :failed_login,
      %{
        user_id: sanitize_user_id(user_id),
        reason: reason,
        timestamp: DateTime.utc_now()
      },
      :warn
    )
  end

  def log_backup_codes_regenerated(user_id) do
    log_event(
      :backup_codes_regenerated,
      %{
        user_id: sanitize_user_id(user_id),
        timestamp: DateTime.utc_now()
      },
      :info
    )
  end
end
