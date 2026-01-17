# Cerebelum Integration Guide

## Overview

This document describes how Thalamus integrates with Cerebelum (the ZEA workflow orchestration engine) to provide secure, auditable authorization for AI agent workflow steps.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Cerebelum                               │
│                    (Workflow Orchestrator)                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ 1. Generate Agent Token
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Thalamus                                │
│                  (Identity & Auth Service)                      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Thalamus.API                          │  │
│  │              (Public Facade Interface)                   │  │
│  └────────────┬─────────────────────────────┬───────────────┘  │
│               │                             │                   │
│               ▼                             ▼                   │
│  ┌────────────────────────┐   ┌────────────────────────────┐  │
│  │  GenerateAgentToken    │   │ ValidateStepAuthorization  │  │
│  │     (Use Case)         │   │      (Use Case)            │  │
│  └────────────────────────┘   └────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            DependencyBuilder                             │  │
│  │      (Dependency Injection Container)                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Integration Methods

Thalamus provides **3 ways** to integrate with Cerebelum:

### 1. Direct Elixir API (Recommended for Umbrella App)

If Cerebelum runs in the same Elixir umbrella app as Thalamus:

```elixir
# In Cerebelum workflow execution
alias Thalamus.API

# Step 1: Generate agent token for workflow
{:ok, token_response} = Thalamus.API.generate_agent_token(%{
  client_id: "cerebelum_client_id",
  client_secret: "cerebelum_secret",
  organization_id: workflow.organization_id,
  delegator_user_id: workflow.created_by_user_id,
  agent_type: "autonomous",
  task_id: workflow.id,
  task_description: "Execute weekly sales report workflow",
  scopes: ["email:send", "reports:read", "calendar:write"]
})

# Store token for workflow execution
workflow_token = token_response.access_token

# Step 2: Before EACH workflow step, validate authorization
{:ok, auth_result} = Thalamus.API.validate_step(
  workflow_token,
  "send_email_step",
  ["email:send"],  # Required scopes for this step
  %{
    workflow_id: workflow.id,
    execution_id: workflow.execution_id,
    step_index: 3
  }
)

if auth_result.authorized do
  # Execute step
  send_email(recipient, subject, body)
else
  # Deny step execution
  {:error, :insufficient_permissions}
end
```

### 2. HTTP API (For External Services)

If Cerebelum runs as a separate service:

```bash
# Step 1: Generate agent token
curl -X POST https://thalamus.zea.ai/oauth/agent-token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "cerebelum_client_id",
    "client_secret": "cerebelum_secret",
    "organization_id": "org_abc123",
    "delegator_user_id": "user_xyz789",
    "agent_type": "autonomous",
    "task_id": "workflow_weekly_report",
    "task_description": "Execute weekly sales report",
    "scope": "email:send reports:read calendar:write"
  }'

# Response:
# {
#   "access_token": "at_abc123...",
#   "token_type": "Bearer",
#   "expires_in": 3600,
#   "agent_type": "autonomous",
#   "task_id": "workflow_weekly_report",
#   "scopes": ["email:send", "reports:read", "calendar:write"]
# }

# Step 2: Validate step authorization
curl -X POST https://thalamus.zea.ai/api/authorization/validate-step \
  -H "Authorization: Bearer at_abc123..." \
  -H "Content-Type: application/json" \
  -d '{
    "step_name": "send_email_step",
    "required_scopes": ["email:send"],
    "context": {
      "workflow_id": "wf_weekly_report",
      "execution_id": "exec_20260117_001",
      "step_index": 3
    }
  }'

# Response:
# {
#   "authorized": true,
#   "agent_id": "agt_xyz789",
#   "agent_type": "autonomous",
#   "scopes": ["email:send", "reports:read", "calendar:write"]
# }
```

### 3. GraphQL API (Future)

Coming soon in v1.1.0.

## Workflow Authorization Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Workflow Execution                           │
└─────────────────────────────────────────────────────────────────┘

1. User triggers workflow
   ├─> Cerebelum requests agent token from Thalamus
   ├─> Thalamus validates user permissions
   ├─> Thalamus generates task-scoped token
   └─> Returns token to Cerebelum

2. For EACH workflow step:
   ├─> Cerebelum calls Thalamus.API.validate_step()
   ├─> Thalamus checks:
   │   ├─> Token exists and is valid
   │   ├─> Token not expired
   │   ├─> Token not revoked
   │   └─> Token has required scopes for this step
   ├─> Thalamus logs authorization decision (audit trail)
   └─> Returns authorization result

3. If authorized:
   ├─> Cerebelum executes step
   └─> Records step execution

4. If denied:
   ├─> Cerebelum stops workflow
   └─> Notifies user of authorization failure
```

## Security Model

### Multi-Tenant Isolation

All operations are scoped to `organization_id`:
- Tokens can only be used within the same organization
- Cross-organization access is prevented
- Token validation checks organization ownership

### Scope-Based Permissions

Scopes follow the format: `resource:action`

Examples:
- `email:send` - Send emails
- `email:read` - Read emails
- `reports:read` - Read reports
- `reports:write` - Create/update reports
- `calendar:read` - Read calendar events
- `calendar:write` - Create/update calendar events

### Token Lifecycle

```
Created → Active → [Revoked|Expired]
  ↓         ↓           ↓
3600s    Validate    Denied
```

- **Created**: Token generated, starts active
- **Active**: Can be used for step validation (max 1 hour)
- **Expired**: Automatically expired after TTL
- **Revoked**: Manually revoked (cannot be reactivated)

### Audit Trail

Every authorization decision is logged:
- **Event**: `step_authorization.granted` or `step_authorization.denied`
- **Actor**: Agent token ID
- **Resource**: Workflow step name
- **Metadata**: Required scopes, decision reason, workflow context
- **Timestamp**: UTC timestamp

## Delegation Chains (Advanced)

Agents can create child agents with narrower permissions:

```elixir
# Parent agent token
{:ok, parent_token} = Thalamus.API.generate_agent_token(%{
  # ... parent params ...
  scopes: ["email:send", "email:read", "reports:read"]
})

# Child agent token (delegated, narrower scopes)
{:ok, child_token} = Thalamus.API.generate_agent_token(%{
  # ... child params ...
  parent_agent_id: parent_token.agent_id,
  scopes: ["email:send"],  # ⚠️ Must be subset of parent scopes
  expires_in: 900  # ⚠️ Must be ≤ parent's remaining TTL
})
```

**Rules**:
- Child scopes ⊆ Parent scopes (strict subset)
- Child TTL ≤ Parent remaining TTL
- Maximum delegation depth: 4 levels
- Revoking parent revokes all children (cascade)

## Rate Limiting

Agent token generation is rate-limited per organization:

- **Production**: 100 tokens/minute per organization
- **Development**: 1000 tokens/minute
- **Test**: Unlimited

If rate limit exceeded:
```json
HTTP 429 Too Many Requests
Retry-After: 42

{
  "error": "rate_limit_exceeded",
  "message": "Maximum 100 agent tokens per 60 seconds per organization",
  "retry_after": 42
}
```

## Error Handling

### Common Errors

| Error Code | HTTP | Description | Resolution |
|------------|------|-------------|------------|
| `invalid_client_credentials` | 401 | Client ID/secret mismatch | Check credentials |
| `delegator_not_found` | 400 | User doesn't exist | Verify user ID |
| `invalid_scopes` | 400 | Scopes not allowed | Check client.allowed_scopes |
| `token_not_found` | 401 | Token doesn't exist | Generate new token |
| `token_expired` | 401 | Token TTL exceeded | Generate new token |
| `token_revoked` | 401 | Token was revoked | Generate new token |
| `insufficient_scopes` | 403 | Missing required scope | Request broader token |
| `invalid_token_format` | 401 | Token format wrong | Use `at_` prefix |

### Example Error Response

```json
{
  "error": "insufficient_scopes",
  "message": "Token lacks required scopes for this operation"
}
```

## Best Practices

### 1. Token Lifecycle Management

```elixir
defmodule CerebelumWorkflow do
  def execute_workflow(workflow) do
    # Generate token at workflow start
    {:ok, token} = generate_workflow_token(workflow)

    try do
      # Execute all steps with same token
      Enum.reduce_while(workflow.steps, :ok, fn step, _acc ->
        case validate_and_execute_step(step, token) do
          {:ok, _result} -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    after
      # Always revoke token when done
      revoke_workflow_token(token)
    end
  end
end
```

### 2. Scope Minimization

Request only the scopes you need:

```elixir
# ❌ BAD: Requesting all scopes
scopes: ["email:send", "email:read", "reports:read", "reports:write",
         "calendar:read", "calendar:write", "admin:delete"]

# ✅ GOOD: Only scopes needed for this workflow
scopes: ["email:send", "reports:read"]
```

### 3. Context Enrichment

Always provide workflow context for better audit trails:

```elixir
# ✅ GOOD: Rich context
Thalamus.API.validate_step(token, "send_email", ["email:send"], %{
  workflow_id: "wf_weekly_report",
  workflow_name: "Weekly Sales Report",
  execution_id: "exec_20260117_001",
  step_index: 3,
  step_name: "send_email_to_team",
  triggered_by: "schedule"
})
```

### 4. Error Recovery

```elixir
def validate_and_execute_step(step, token) do
  case Thalamus.API.validate_step(token, step.name, step.required_scopes) do
    {:ok, %{authorized: true}} ->
      execute_step(step)

    {:error, :token_expired} ->
      # Token expired mid-workflow, regenerate
      {:ok, new_token} = regenerate_token()
      validate_and_execute_step(step, new_token)

    {:error, :insufficient_scopes} ->
      # Hard failure - workflow misconfigured
      {:error, :workflow_permission_denied}

    {:error, reason} ->
      {:error, reason}
  end
end
```

## Monitoring & Observability

### Metrics to Track

1. **Token Generation Rate**
   - Metric: `thalamus.agent_tokens.generated`
   - Alert: > 1000/min per org (potential abuse)

2. **Authorization Success Rate**
   - Metric: `thalamus.step_auth.granted / total`
   - Alert: < 95% (configuration issues)

3. **Token Expiration Rate**
   - Metric: `thalamus.step_auth.denied{reason=token_expired}`
   - Alert: > 10% (TTL too short)

4. **Average Token Lifetime**
   - Metric: `thalamus.agent_tokens.lifetime_seconds`
   - Expected: ~600-1800s (10-30 min workflows)

### Audit Log Queries

```elixir
# Find all denied authorizations for organization
AuditLog.query(%{
  event_type: "step_authorization.denied",
  organization_id: org_id,
  time_range: last_24_hours()
})

# Find tokens with excessive scopes
AuditLog.query(%{
  event_type: "agent_token.created",
  "metadata.scopes_count": {:gt, 5}
})
```

## Migration Guide

If you're migrating from direct OAuth2 tokens:

### Before (OAuth2 User Token)
```elixir
# User logs in, gets long-lived token
{:ok, user_token} = authenticate_user(email, password)

# Use same token for everything
send_email(user_token, ...)
read_report(user_token, ...)
```

### After (Agent Token)
```elixir
# Generate task-scoped agent token
{:ok, agent_token} = Thalamus.API.generate_agent_token(%{
  delegator_user_id: user.id,
  task_description: "Send weekly report",
  scopes: ["email:send", "reports:read"]
})

# Validate before each action
{:ok, _} = Thalamus.API.validate_step(agent_token, "send_email", ["email:send"])
send_email(...)

{:ok, _} = Thalamus.API.validate_step(agent_token, "read_report", ["reports:read"])
read_report(...)
```

## Support

For questions or issues:
- Documentation: https://docs.zea.ai/thalamus/cerebelum-integration
- GitHub Issues: https://github.com/zea/thalamus/issues
- Email: support@zea.ai
