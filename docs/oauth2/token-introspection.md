# Token Introspection (RFC 7662)

Validate an access token and retrieve its metadata. Resource servers use this to check if a token is still active and what scopes it carries.

---

## Endpoint

```
POST /oauth/introspect
Content-Type: application/x-www-form-urlencoded
```

---

## Request

```bash
curl -X POST http://localhost:4000/oauth/introspect \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=at_abc123def456..." \
  -d "token_type_hint=access_token"
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `token` | ✅ | The token to introspect |
| `token_type_hint` | ❌ | Hint: `access_token` or `refresh_token` |

> **Note**: Client authentication for the introspection endpoint is not enforced in the current version. In production, this should be behind authentication.

---

## Active Token Response

```json
{
  "active": true,
  "scope": "openid profile email",
  "client_id": "client_abc123",
  "token_type": "Bearer",
  "sub": "user_abc123",
  "user_id": "user_abc123",
  "username": "user_abc123",
  "email": "user@example.com",
  "organization_id": "660e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "660e8400-e29b-41d4-a716-446655440000",
  "exp": 1640995200,
  "iat": 1640991600
}
```

### Standard Fields (RFC 7662)

| Field | Description |
|---|---|
| `active` | `true` if token is valid and not expired |
| `scope` | Space-separated list of granted scopes |
| `client_id` | OAuth2 client that the token was issued to |
| `token_type` | Always `Bearer` |
| `sub` | Subject identifier (user ID) |
| `exp` | Expiration timestamp (Unix seconds) |
| `iat` | Issued-at timestamp (Unix seconds) |

### Extended Fields

| Field | Description |
|---|---|
| `user_id` | User UUID |
| `username` | User ID (same as `sub`) |
| `email` | User email (if available) |
| `organization_id` | Organization UUID |
| `tenant_id` | Same as `organization_id` (for compatibility) |

### Agent Token Fields

When introspecting an agent token, additional fields are returned:

| Field | Description |
|---|---|
| `agent_type` | `autonomous`, `supervisor`, or `tool` |
| `delegated_by` | ID of the delegating user/agent |
| `delegation_chain` | Full delegation chain |
| `delegation_depth` | Depth in the delegation tree |
| `task_id` | External task identifier |
| `task_type` | Type of task |
| `task_scopes` | Task-scoped permissions |
| `max_operations` | Maximum operations allowed |
| `operations_remaining` | Operations remaining |
| `expires_on_completion` | Whether token expires on task completion |
| `intent_description` | Human-readable task description |
| `orchestrator_id` | Orchestrator agent ID |
| `environment` | Execution environment |

---

## Inactive Token Response

```json
{
  "active": false
}
```

A token is considered inactive if it:
- Is expired
- Has been revoked
- Has an invalid format
- Was never issued
- Any other validation error

> Per RFC 7662 §2.2, the response is always `200 OK` — the `active` field indicates the token state.

---

## Python Example

```python
import httpx

def introspect_token(token: str) -> dict:
    response = httpx.post(
        "http://localhost:4000/oauth/introspect",
        data={
            "token": token,
            "token_type_hint": "access_token"
        }
    )
    response.raise_for_status()
    result = response.json()

    if result["active"]:
        print(f"Token active for user {result.get('email', 'unknown')}")
        print(f"Scopes: {result['scope']}")
        print(f"Organization: {result.get('organization_id')}")
    else:
        print("Token is inactive")

    return result
```

---

## Node.js Example

```javascript
async function introspectToken(token) {
  const params = new URLSearchParams();
  params.append('token', token);
  params.append('token_type_hint', 'access_token');

  const response = await fetch('http://localhost:4000/oauth/introspect', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params
  });

  const result = await response.json();

  if (result.active) {
    console.log(`Token active | User: ${result.email} | Scopes: ${result.scope}`);
  } else {
    console.log('Token inactive');
  }

  return result;
}
```

---

## Caching

Token introspection results are cached via `CachedValidateToken` using Redis. This reduces database load for repeated introspection calls.

---

## See Also

- [OAuth2 Overview](overview.md) — All grants and endpoints
- [Token Revocation](token-revocation.md) — Revoke tokens (RFC 7009)
- [UserInfo Endpoint](userinfo.md) — Get user data from a token
