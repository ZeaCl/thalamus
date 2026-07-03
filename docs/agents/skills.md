# Agent Skills Catalog

Skills are scopes that an agent declares to access resources and perform operations. Each skill maps to a specific permission validated by Thalamus before every workflow step.

---

## Skill Format

Skills follow the OAuth2 scope format:

```
resource:action
```

| Component | Description | Example |
|---|---|---|
| `resource` | Resource domain | `email`, `customer`, `db` |
| `action` | Operation type | `read`, `write`, `send`, `delete` |

Agent tokens declare skills as a space-separated list in the `scope` parameter.

---

## Standard Skills

Always available, defined by OpenID Connect:

| Skill | Description | Agent Use |
|---|---|---|
| `openid` | Basic identity | Required for any agent acting as a user |
| `profile` | Profile details (name, picture) | Displaying user context |
| `email` | Email address access | Sending notifications, identifying users |
| `address` | Physical address | Location-based operations |
| `phone` | Phone number | SMS/call operations |
| `offline_access` | Long-lived sessions | **Restricted** — requires special permission |

---

## Domain Skills

Configurable via `config :thalamus, :oauth2_scopes`:

### Default Scopes

| Skill | Description | Agent Type |
|---|---|---|
| `api:read` | Read API resources | `autonomous`, `supervisor`, `tool` |
| `api:write` | Create/update API resources | `autonomous`, `supervisor` |
| `api:admin` | **Restricted** — Admin operations | `supervisor` only |
| `data:read` | Read data stores | `autonomous`, `supervisor`, `tool` |
| `data:write` | Write to data stores | `autonomous`, `supervisor` |
| `webhooks:manage` | Manage webhook subscriptions | `supervisor` |
| `billing:read` | Read billing information | `autonomous`, `supervisor` |
| `billing:write` | **Restricted** — Modify billing | `supervisor` only |

### ZEA Platform Scopes

| Skill | Description | Agent Type |
|---|---|---|
| `zea:read` | ZEA platform read access | `autonomous`, `supervisor`, `tool` |
| `zea:write` | ZEA platform write access | `autonomous`, `supervisor` |
| `zea:admin` | ZEA platform admin | `supervisor` only |
| `synapse:events` | Event stream access | `autonomous`, `tool` |
| `cortex:chat` | LLM chat access | `autonomous`, `supervisor` |
| `organizations:write` | Organization management | `supervisor` only |

---

## Skills by Agent Type

### `autonomous` — Independent AI Agents

Self-directed agents that make decisions and execute multi-step workflows.

**Recommended skills:**
```
openid profile email data:read data:write api:read cortex:chat
```

**Use cases:** code generation, data analysis, document processing, customer support

---

### `supervisor` — Orchestration Agents

Coordinate and oversee other agents, route tasks, enforce policies.

**Recommended skills:**
```
openid profile email api:read api:write organizations:write webhooks:manage cortex:chat
```

**Use cases:** task routing, quality control, compliance enforcement, multi-agent orchestration

---

### `tool` — Single-Purpose Agents

Execute one type of operation with minimal permissions.

**Recommended skills:**
```
openid data:read
```

**Use cases:** file I/O, API calls, search, data transformation, email sending

---

## Skill Validation

### At Token Creation

When an agent token is created via `POST /oauth/agent-token`:

1. **Client check**: Requested scopes must be ⊆ client's `allowed_scopes`
2. **Parent check** (delegation): Child scopes must be ⊆ parent token's scopes
3. **Organization check**: Org compliance rules may forbid certain scopes
4. **Invalid scopes rejected**: Returns error with list of invalid scopes

```json
HTTP/1.1 400 Bad Request
{
  "error": {
    "code": "invalid_scope",
    "message": "invalid scopes: admin:all, billing:delete"
  }
}
```

### At Step Execution

Cerebelum calls `POST /api/authorization/validate-step` before each workflow step:

1. Token's scopes are loaded: `["email:send", "customer:read", "db:query"]`
2. Step's required scopes are checked: `["email:send"]`
3. **Subset check**: required ⊆ token scopes → authorized
4. If missing → **403 Forbidden**

```
Token scopes:   [email:send, customer:read, db:query]
Step requires:  [email:send]              → ✅ Authorized
Step requires:  [admin:write]             → ❌ Forbidden
```

---

## Custom Skills

Add custom skills via application config:

```elixir
# config/config.exs
config :thalamus, :oauth2_scopes, %{
  custom_scopes: [
    "customer:read",
    "customer:write",
    "email:send",
    "report:generate",
    "db:query",
    "db:migrate",
    "ml:train",
    "ml:predict"
  ],
  restricted_scopes: [
    "api:admin",
    "billing:write",
    "db:migrate",
    "ml:train"
  ]
}
```

**Restricted scopes** require special permission — typically granted only to `supervisor` agents.

---

## Agent Config Skills

Agent skills can also be defined per-user via `agent_config`:

```json
{
  "skills": ["gestion-fondos", "dominio-fondos", "analisis-riesgo"],
  "system_prompt": "Eres un asistente financiero experto en fondos de inversión...",
  "model": "deepseek/deepseek-chat"
}
```

These are **declarative skills** used by the agent runtime (Pi) — distinct from OAuth2 scopes. The `agent_config` is retrieved via:

```
GET /api/internal/users/:user_id/agent-config
```

---

## Best Practices

### Principle of Least Privilege

Request only the scopes needed for the specific task:

```bash
# ❌ Too broad
"scope": "api:read api:write api:admin data:read data:write"

# ✅ Just what's needed
"scope": "data:read email:send"
```

### Task-Scoped Tokens

Create separate tokens for separate tasks:

```bash
# Token 1: Data analysis (read-only)
{ "task_description": "Analyze Q4", "scope": "data:read" }

# Token 2: Send report (write)
{ "task_description": "Send Q4 report", "scope": "data:read email:send" }
```

### Time-Limited Tokens

Set `expires_in` to the minimum needed:

```bash
# ❌ Max allowed
"expires_in": 3600

# ✅ Realistic estimate
"expires_in": 600
```

---

## See Also

- [Agent Overview](overview.md) — Architecture and concepts
- [Agent CLI Reference](cli.md) — All agent endpoints
- [Agent Tokens (OAuth2)](../oauth2/agent-tokens.md) — Token endpoint details
- [Validate Step Authorization](../oauth2/token-introspection.md) — Step authorization flow
