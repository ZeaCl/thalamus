# Agent CLI Reference

HTTP endpoints that agents use for authentication, token management, and step authorization. These serve the same function a CLI would — callable from any agent runtime.

---

## Base URL

| Environment | URL |
|---|---|
| ZEA Cloud | `https://auth.zea.cl` |
| On-Premise | `http://localhost:4000` |

---

## Commands (Endpoints)

### Create Agent Token

Generate a task-scoped access token for an AI agent.

```bash
POST /oauth/agent-token
Content-Type: application/json
```

```bash
curl -X POST https://auth.zea.cl/oauth/agent-token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "client_xxx",
    "client_secret": "secret_xxx",
    "organization_id": "org_abc123",
    "delegator_user_id": "user_xyz789",
    "agent_type": "autonomous",
    "task_description": "Analyze Q4 sales data",
    "scope": "read:data write:results",
    "expires_in": 1800,
    "reason": "Scheduled weekly analysis"
  }'
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `client_id` | ✅ | OAuth2 client ID |
| `client_secret` | ✅ | OAuth2 client secret |
| `organization_id` | ✅ | Organization UUID |
| `delegator_user_id` | ✅ | Human authorizer user UUID |
| `agent_type` | ✅ | `autonomous`, `supervisor`, `tool` |
| `task_description` | ✅ | Human-readable task (sanitized) |
| `scope` | ✅ | Space-separated scopes |
| `expires_in` | ❌ | TTL in seconds (max 3600) |
| `task_id` | ❌ | External task UUID (auto-generated if omitted) |
| `parent_agent_id` | ❌ | Parent token UUID for delegation |
| `reason` | ❌ | Intent for audit trail (sanitized) |

**Response:**
```json
{
  "access_token": "at_abc123def456...",
  "token_type": "Bearer",
  "expires_in": 1800,
  "scope": "read:data write:results",
  "agent_type": "autonomous",
  "task_id": "task_abc123",
  "task_description": "Analyze Q4 sales data",
  "delegation_depth": 0,
  "reason": "Scheduled weekly analysis"
}
```

---

### Introspect Token

Check token state and metadata.

```bash
POST /oauth/introspect
Content-Type: application/x-www-form-urlencoded
```

```bash
curl -X POST https://auth.zea.cl/oauth/introspect \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=at_abc123def456..." \
  -d "token_type_hint=access_token"
```

**Agent-specific response:**
```json
{
  "active": true,
  "scope": "read:data write:results",
  "client_id": "client_xxx",
  "agent_type": "autonomous",
  "delegated_by": "user_xyz789",
  "delegation_chain": "...",
  "delegation_depth": 0,
  "task_id": "task_abc123",
  "task_type": "analysis",
  "max_operations": 100,
  "operations_remaining": 95,
  "expires_on_completion": true,
  "intent_description": "Analyze Q4 sales data",
  "orchestrator_id": null,
  "environment": "production"
}
```

---

### Revoke Token

Revoke an agent token (stops the agent immediately).

```bash
POST /oauth/revoke
Authorization: Basic base64(client_id:client_secret)
Content-Type: application/x-www-form-urlencoded
```

```bash
curl -X POST https://auth.zea.cl/oauth/revoke \
  -H "Authorization: Basic $(echo -n 'client_xxx:secret_xxx' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=at_abc123def456..." \
  -d "token_type_hint=access_token"
```

**Response:** `200 OK` (always, per RFC 7009)

---

### Validate Step Authorization

Called by Cerebelum before executing each workflow step.

```bash
POST /api/authorization/validate-step
Authorization: Bearer at_abc123...
Content-Type: application/json
```

```bash
curl -X POST https://auth.zea.cl/api/authorization/validate-step \
  -H "Authorization: Bearer at_abc123def456..." \
  -H "Content-Type: application/json" \
  -d '{
    "step_name": "fetch_customer_data",
    "required_scopes": ["customer:read", "db:query"],
    "context": {
      "workflow_id": "wf_123",
      "execution_id": "exec_456"
    }
  }'
```

**Response (authorized):**
```json
{
  "authorized": true,
  "agent_id": "agt_xyz789",
  "agent_type": "autonomous",
  "scopes": ["customer:read", "db:query", "email:send"]
}
```

**Error responses:**

| Status | Code | When |
|---|---|---|
| `401` | `unauthorized` | Missing/invalid Bearer token |
| `401` | `token_expired` | Token has expired |
| `401` | `token_revoked` | Token has been revoked |
| `403` | `insufficient_scopes` | Token lacks required scopes |
| `422` | `invalid_request` | Missing step_name or required_scopes |

---

### Get Agent Config (Internal)

Look up agent configuration for a user. Used by Pi backend and other microservices.

```bash
GET /api/internal/users/:user_id/agent-config
```

```bash
curl http://thalamus:4000/api/internal/users/user_abc123/agent-config
```

**Response (user is an agent):**
```json
{
  "data": {
    "id": "user_abc123",
    "is_agent": true,
    "agent_config": {
      "skills": ["gestion-fondos", "dominio-fondos"],
      "system_prompt": "Eres un asistente financiero...",
      "model": "deepseek/deepseek-chat"
    }
  }
}
```

---

### Create Internal Agent Token (Internal)

Generate a short-lived PAT-based token for agents via internal microservices.

```bash
POST /api/internal/agent-token
Content-Type: application/json
```

```bash
curl -X POST http://thalamus:4000/api/internal/agent-token \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_xyz789",
    "scopes": ["venture:read", "venture:write"],
    "organization_id": "org_abc123"
  }'
```

**Response:**
```json
{
  "token": "th_pat_live_abc123...",
  "scopes": ["venture:read", "venture:write"],
  "expires_in": 3600
}
```

---

## Full Agent Lifecycle

```bash
# 1. Agent backend starts a task
TOKEN=$(curl -s -X POST https://auth.zea.cl/oauth/agent-token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "client_xxx",
    "client_secret": "secret_xxx",
    "organization_id": "org_abc123",
    "delegator_user_id": "user_xyz789",
    "agent_type": "autonomous",
    "task_description": "Process customer inquiries",
    "scope": "customer:read email:send"
  }' | jq -r '.access_token')

# 2. Cerebelum validates each step
curl -X POST https://auth.zea.cl/api/authorization/validate-step \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "step_name": "send_email",
    "required_scopes": ["email:send"]
  }'

# 3. Check token status mid-workflow
curl -X POST https://auth.zea.cl/oauth/introspect \
  -d "token=$TOKEN"

# 4. Revoke when task is complete
curl -X POST https://auth.zea.cl/oauth/revoke \
  -H "Authorization: Basic $(echo -n 'client_xxx:secret_xxx' | base64)" \
  -d "token=$TOKEN"
```

---

## See Also

- [Agent Overview](overview.md) — Architecture and concepts
- [Skills Catalog](skills.md) — Available scopes per agent type
- [Agent Tokens (OAuth2)](../oauth2/agent-tokens.md) — Token endpoint details
- [Token Introspection](../oauth2/token-introspection.md) — Full introspection reference
