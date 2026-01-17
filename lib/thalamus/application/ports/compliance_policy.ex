defmodule Thalamus.Application.Ports.CompliancePolicy do
  @moduledoc """
  Behaviour for industry-specific compliance validation policies.

  This port allows different organizations to implement vertical-specific
  compliance requirements (HIPAA for healthcare, PCI-DSS for fintech, etc.)
  while keeping the core use cases generic.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for compliance validation
  - Dependency Inversion: Use cases depend on this abstraction, not concrete implementations
  - Open/Closed: New compliance policies can be added without modifying existing code

  ## Usage

  Organizations are configured with a specific compliance policy module in their settings.
  The use case then delegates compliance-specific validation to the configured policy.

      iex> policy = organization.compliance_policy_module # HealthcareCompliancePolicy
      iex> policy.validate_delegation(delegator, agent_request, context)
      {:ok, :authorized}

  ## Context

  The context parameter is a map containing all relevant information for validation:
  - `:organization` - The organization entity
  - `:delegator` - The user delegating authority
  - `:client` - The OAuth2 client
  - `:request` - The agent token request
  - `:parent_token` - Parent token if this is a delegation (optional)

  ## Callbacks

  All callbacks return:
  - `{:ok, term()}` on successful validation
  - `{:error, atom() | String.t()}` on validation failure
  """

  alias Thalamus.Application.DTOs.AgentTokenRequest
  alias Thalamus.Domain.Entities.{User, Organization, OAuth2Client, AgentToken}

  @type context :: %{
          organization: Organization.t(),
          delegator: User.t(),
          client: OAuth2Client.t(),
          request: AgentTokenRequest.t(),
          parent_token: AgentToken.t() | nil
        }

  @type validation_result :: {:ok, term()} | {:error, atom() | String.t()}

  @doc """
  Validates whether the delegator has permission to create an agent token
  with the requested parameters.

  ## Examples

      # Healthcare: Check if user has access to patient data
      validate_delegation(delegator, request, context)
      {:ok, :authorized}

      # Fintech: Check transaction limits and MFA requirements
      validate_delegation(delegator, request, context)
      {:error, :mfa_required}
  """
  @callback validate_delegation(User.t(), AgentTokenRequest.t(), context()) :: validation_result()

  @doc """
  Validates the requested scopes against compliance requirements.

  May enforce scope narrowing, forbidden scopes, or require additional scopes.

  ## Examples

      # Healthcare: Ensure PHI access requires consent scope
      validate_scopes(["patient:read"], context)
      {:error, :consent_scope_required}

      # Fintech: Limit transaction scopes
      validate_scopes(["transactions:write"], context)
      {:error, :scope_exceeds_limit}
  """
  @callback validate_scopes([String.t()], context()) :: validation_result()

  @doc """
  Validates token parameters (TTL, task description, etc.) for compliance.

  May enforce maximum TTL, required metadata, or forbidden task patterns.

  ## Examples

      # Government: Enforce maximum 1-hour TTL for classified operations
      validate_token_params(%{expires_in: 7200}, context)
      {:error, :ttl_exceeds_maximum}

      # Healthcare: Require patient_id in task description
      validate_token_params(%{task_description: "Data export"}, context)
      {:error, :patient_id_required}
  """
  @callback validate_token_params(map(), context()) :: validation_result()

  @doc """
  Validates delegation chain depth and hierarchy.

  May enforce stricter depth limits or validate clearance levels.

  ## Examples

      # Government: Ensure clearance doesn't increase in chain
      validate_delegation_chain(delegation_chain, context)
      {:error, :clearance_escalation_forbidden}

      # Fintech: Limit delegation depth for high-value operations
      validate_delegation_chain(delegation_chain, context)
      {:error, :depth_exceeds_limit}
  """
  @callback validate_delegation_chain(term(), context()) :: validation_result()

  @doc """
  Enriches audit log with compliance-specific metadata.

  Returns additional fields to include in audit logs for compliance reporting.

  ## Examples

      # Healthcare: Add PHI access tracking
      enrich_audit_log(token, context)
      {:ok, %{phi_accessed: true, patient_id: "123", consent_id: "456"}}

      # Fintech: Add transaction tracking
      enrich_audit_log(token, context)
      {:ok, %{transaction_limit: 10000, mfa_verified: true}}
  """
  @callback enrich_audit_log(AgentToken.t(), context()) :: {:ok, map()} | {:error, term()}

  @doc """
  Optional callback to perform post-creation actions.

  Can be used to notify compliance systems, update external registries, etc.

  ## Examples

      # Healthcare: Notify HIPAA audit system
      after_token_creation(token, context)
      {:ok, :notified}

      # Government: Register token in clearance tracking system
      after_token_creation(token, context)
      {:ok, :registered}
  """
  @callback after_token_creation(AgentToken.t(), context()) :: {:ok, term()} | {:error, term()}

  @optional_callbacks [after_token_creation: 2]
end
