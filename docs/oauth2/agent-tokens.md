# Agent Tokens

Specialized access tokens for AI agents with task-scoping, delegation tracking, and compliance-ready audit trails.

---

## Overview

Agent tokens extend standard OAuth2 tokens with:

- **Task-scoping**: Tokens bound to a specific task
- **Delegation tracking**: Full chain of delegation (human → agent → sub-agent)
- **Operation limits**: Max operations with auto-revocation
- **Compliance**: EU AI Act-ready audit trail
- **Feature flag**: Gated behind `agent_tokens_enabled` feature flag

---

## Endpoint

```
POST /oauth/agent-token
Content-Type: application/json
```

> **Feature flag**: If `agent_tokens_enabled` is `false`, the endpoint returns `404 Not Found`.

---

## Request

```bash
curl -X POST http://localhost:4000/oauth/agent-token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "client_xxx",
    "client_secret": "secret_xxx",
    "organization_id": "660e8400-e29b-41d4-a716-446655440000",
    "delegator_user_id": "user_abc123",
    "agent_type": "autonomous",
    "task_description": "Process customer support ticket #1234",
    "scope": "read:data write:results",
    "task_id": "task_abc123",
    "expires_in": 1800,
    "reason": "Automated ticket triage"
  }'
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `client_id` | ✅ | OAuth2 client ID |
| `client_secret` | ✅ | OAuth2 client secret |
| `organization_id` | ✅ | Organization UUID |
| `delegator_user_id` | ✅ | Human user ID authorizing the agent |
| `agent_type` | ✅ | `autonomous`, `supervisor`, or `tool` |
| `task_description` | ✅ | Human-readable task description |
| `scope` | ✅ | Space-separated scopes (subset of client's) |
| `task_id` | ❌ | External task UUID |
| `expires_in` | ❌ | TTL in seconds (max: 3600, default: 3600) |
| `reason` | ❌ | Reason/intent for audit trail |
| `parent_agent_id` | ❌ | Parent agent token ID for delegation chains |

---

## Agent Types

| Type | Description | Typical Use |
|---|---|---|
| `autonomous` | Self-directed AI agent | Code generation, data analysis |
| `supervisor` | Oversight/orchestration agent | Task routing, quality control |
| `tool` | Single-purpose agent tool | File processing, API calls |

---

## Success Response

```json
{
  "access_token": "at_abc123def456...",
  "token_type": "Bearer",
  "expires_in": 1800,
  "scope": "read:data write:results",
  "agent_type": "autonomous",
  "task_id": "task_abc123",
  "task_description": "Process customer support ticket #1234",
  "delegation_depth": 0,
  "reason": "Automated ticket triage"
}
```

| Field | Description |
|---|---|
| `access_token` | Bearer token for API requests |
| `token_type` | Always `Bearer` |
| `expires_in` | Seconds until expiration |
| `scope` | Granted scopes |
| `agent_type` | Agent type |
| `task_id` | Task UUID |
| `task_description` | Human-readable description |
| `delegation_depth` | Depth in delegation chain (0 = direct from human) |
| `reason` | Intent/reason for audit |

---

## Error Responses

### Validation Errors (400)

```json
{
  "error": {
    "code": "invalid_request",
    "message": "delegator_user_id is required",
    "documentation_url": "https://docs.thalamus.io/errors/invalid_request",
    "request_id": "req_abc123",
    "timestamp": "2026-01-01T00:00:00Z",
    "details": {}
  }
}
```

### Common Error Codes

| Code | Meaning |
|---|---|
| `invalid_request` | Missing or invalid parameter |
| `invalid_client` | Client authentication failed |
| `invalid_scope` | Scopes not allowed for client |
| `server_error` | Internal error |

### Specific Validation Errors

| Error | When |
|---|---|
| `delegator_user_id not found` | Delegator user doesn't exist |
| `delegating user is inactive` | Delegator account is disabled |
| `agent_type must be autonomous, supervisor, or tool` | Invalid agent type |
| `task_description cannot be empty` | Empty description |
| `expires_in cannot exceed 3600 seconds` | TTL too high |
| `delegation chain exceeds maximum depth of 4` | Too many nested delegations |
| `parent_agent_id not found` | Parent token doesn't exist |
| `parent agent token is not active` | Parent token expired/revoked |

---

## Delegation Chains

Agent tokens support delegation chains (agent → sub-agent):

```
Human User (delegator_user_id)
  └── Agent Token A (delegation_depth: 0)
        └── Agent Token B (delegation_depth: 1, parent_agent_id: A)
              └── Agent Token C (delegation_depth: 2, parent_agent_id: B)
```

- **Maximum depth**: 4 levels
- **Parent validation**: Parent token must exist, be active, and belong to the same organization
- **Chain tracking**: Full delegation chain visible in introspection

---

## Introspection

When introspecting an agent token via `POST /oauth/introspect`, additional fields are returned:

```json
{
  "active": true,
  "scope": "read:data write:results",
  "client_id": "client_xxx",
  "agent_type": "autonomous",
  "delegated_by": "user_abc123",
  "delegation_chain": "...",
  "delegation_depth": 1,
  "task_id": "task_abc123",
  "task_type": "...",
  "task_scopes": "...",
  "max_operations": 100,
  "operations_remaining": 95,
  "expires_on_completion": true,
  "intent_description": "Process customer support ticket #1234",
  "orchestrator_id": "agent_xyz",
  "environment": "production"
}
```

---

## Python Example

```python
import httpx

def create_agent_token(
    client_id: str,
    client_secret: str,
    org_id: str,
    user_id: str,
    task: str,
    scopes: list[str],
    agent_type: str = "autonomous"
) -> dict:
    response = httpx.post(
        "http://localhost:4000/oauth/agent-token",
        json={
            "client_id": client_id,
            "client_secret": client_secret,
            "organization_id": org_id,
            "delegator_user_id": user_id,
            "agent_type": agent_type,
            "task_description": task,
            "scope": " ".join(scopes)
        }
    )
    response.raise_for_status()
    return response.json()

# Usage
token_data = create_agent_token(
    client_id="client_xxx",
    client_secret="secret_xxx",
    org_id="660e8400-e29b-41d4-a716-446655440000",
    user_id="user_abc123",
    task="Analyze sales data for Q4",
    scopes=["read:data", "write:results"]
)
print(f"Agent token: {token_data['access_token']}")
print(f"Expires in: {token_data['expires_in']}s")
```

---

## See Also

- [OAuth2 Overview](overview.md) — All grants and endpoints
- [Token Introspection](token-introspection.md) — Agent token metadata
- [Admin API Keys](../guides/admin-api-keys.md) — Service-to-service auth
