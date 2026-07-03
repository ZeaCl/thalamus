# Agent Tokens — Overview

How AI agents authenticate with Thalamus and act on behalf of users with task-scoped permissions.

---

## What is an Agent Token?

An agent token is a specialized OAuth2 access token that grants an AI agent permission to act on behalf of a human user for a **specific, time-limited task**. Unlike standard OAuth2 tokens:

| Feature | User Token | Agent Token |
|---|---|---|
| **Issued to** | User (via app) | OAuth2 client (M2M) |
| **Scoped to** | App's registered scopes | Specific task + delegation chain |
| **Delegation** | None | Full chain: human → agent → sub-agent |
| **Max TTL** | 3600s (1h) | 3600s (1h), configurable per org |
| **Max depth** | N/A | 4 levels |
| **Compliance** | Basic audit | EU AI Act-ready: intent, task, chain |
| **Feature flag** | Always on | Gated behind `agent_tokens_enabled` |

---

## Architecture

```
┌──────────┐                    ┌──────────────┐
│  Human   │ ─── delegates ──→  │  AI Agent    │
│  User    │                    │  (autonomous)│
└──────────┘                    └──────┬───────┘
                                       │
                         ① POST /oauth/agent-token
                            client_id + client_secret
                            delegator_user_id
                            agent_type + task + scopes
                                       │
                                       ▼
                               ┌──────────────┐
                               │   Thalamus   │
                               │  OAuth2 /    │
                               │  AgentToken  │
                               └──────┬───────┘
                                      │
                         ② Returns access_token
                            with task scoping
                                      │
                                      ▼
                               ┌──────────────┐
                               │  Cerebelum   │
                               │  (workflow)  │
                               └──────┬───────┘
                                      │
                         ③ Before each step:
                            POST /api/authorization/
                                 validate-step
                                      │
                         ④ Thalamus validates:
                            token not expired
                            token not revoked
                            token has required scopes
                                      │
                              ┌───────┴───────┐
                              ▼               ▼
                         ✅ Authorized    ❌ Denied
                         execute step     stop workflow
```

---

## Agent Types

| Type | Behavior | Typical Use |
|---|---|---|
| `autonomous` | Makes independent decisions, executes multi-step workflows | Code generation, data analysis |
| `supervisor` | Coordinates and oversees other agents, routes tasks | Task orchestration, quality control |
| `tool` | Single-purpose, executes one type of operation | File I/O, API calls, search |

---

## Delegation Chains

Agents can delegate to sub-agents, forming a chain:

```
Human (delegator_user_id)
  └── Agent A (depth: 0, root)
        ├── Agent B (depth: 1, parent: A)
        │     └── Agent C (depth: 2, parent: B)
        └── Agent D (depth: 1, parent: A)
```

**Rules:**
- Maximum depth: **4 levels**
- Child token TTL must be ≤ parent's remaining TTL
- Child scopes must be ⊆ parent's scopes (scope narrowing)
- Parent token must be active when child is created
- Full chain is tracked and visible in introspection

---

## Authentication Flows

### Flow 1: M2M Agent Token (for autonomous/supervisor agents)

```bash
# Agent backend authenticates with client credentials
curl -X POST https://auth.zea.cl/oauth/agent-token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "client_xxx",
    "client_secret": "secret_xxx",
    "organization_id": "org_abc123",
    "delegator_user_id": "user_xyz789",
    "agent_type": "autonomous",
    "task_description": "Analyze Q4 sales data",
    "scope": "read:data write:results"
  }'
```

### Flow 2: Internal Agent Token (for microservices like Pi backend)

```bash
# Called from within the internal network (no auth required)
curl -X POST http://thalamus:4000/api/internal/agent-token \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_xyz789",
    "scopes": ["venture:read", "venture:write"],
    "organization_id": "org_abc123"
  }'
```

Returns a short-lived Personal Access Token (PAT) scoped to the user.

---

## Step Authorization (Cerebelum Integration)

Before executing each workflow step, Cerebelum calls Thalamus to validate:

```
POST /api/authorization/validate-step
Authorization: Bearer at_abc123...
Content-Type: application/json

{
  "step_name": "send_email",
  "required_scopes": ["email:send", "email:read"],
  "context": {
    "workflow_id": "wf_weekly_report",
    "execution_id": "exec_123"
  }
}
```

**Response (authorized):**
```json
{
  "authorized": true,
  "agent_id": "agt_xyz789",
  "agent_type": "autonomous",
  "scopes": ["email:send", "email:read", "calendar:read"]
}
```

**Response (denied — insufficient scopes):**
```json
HTTP/1.1 403 Forbidden
{
  "error": "insufficient_scopes",
  "message": "Token lacks required scopes for this operation"
}
```

### Validation Steps

1. **Token format**: Must start with `at_`
2. **Token exists**: Found in agent token repository
3. **Not expired**: Current time < created_at + expires_in
4. **Not revoked**: status == `:active`
5. **Has required scopes**: requested_scopes ⊆ token.scopes
6. **Audit logged**: Every check logged (granted or denied)

---

## Getting Agent Config

Microservices can look up a user's agent configuration:

```
GET /api/internal/users/user_abc123/agent-config
```

**Response (user is an agent):**
```json
{
  "data": {
    "id": "user_abc123",
    "is_agent": true,
    "agent_config": {
      "skills": ["gestion-fondos", "dominio-fondos"],
      "system_prompt": "Eres un asistente especializado...",
      "model": "deepseek/deepseek-chat"
    }
  }
}
```

---

## Compliance & Audit

Every agent token operation is logged:

| Event | When |
|---|---|
| `agent_token.created` | Token generated via `/oauth/agent-token` |
| `step_authorization.granted` | Step validation passed |
| `step_authorization.denied` | Step validation failed |

Each log entry includes: agent type, task description, delegation depth, delegator user, scopes, reason, IP, user agent, request ID, environment.

---

## Organization Compliance Rules

Organizations can configure compliance policies (via `compliance_config`):

```json
{
  "max_token_ttl": 1800,
  "forbidden_agent_types": [],
  "allowed_hours": { "start": 8, "end": 18 },
  "require_mfa_for_scopes": ["admin:write"],
  "max_delegation_depth": 3
}
```

If configured, these rules are enforced at token creation time.

---

## Feature Flag

Agent tokens are gated behind `agent_tokens_enabled`. When disabled:

```json
HTTP/1.1 404 Not Found
{
  "error": "not_found",
  "error_description": "Endpoint not available"
}
```

---

## See Also

- [Agent CLI Reference](cli.md) — All endpoints an agent uses
- [Skills Catalog](skills.md) — Available scopes by agent type
- [Agent Tokens (OAuth2)](../oauth2/agent-tokens.md) — Token endpoint reference
- [Token Introspection](../oauth2/token-introspection.md) — Agent token metadata
