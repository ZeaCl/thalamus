# Client Credentials (M2M)

Machine-to-machine authentication for backend services, CI/CD pipelines, and cron jobs. No user interaction required.

---

## Flow Overview

```
Service ──→ POST /oauth/token
             grant_type=client_credentials
             &client_id=client_xxx
             &client_secret=secret_xxx
             &scope=read:data+write:results

Service ←── { access_token, expires_in, scope }
```

> **No refresh token is issued** for client credentials. When the token expires, request a new one.

---

## Request

```bash
curl -X POST http://localhost:4000/oauth/token \
  -H "Authorization: Basic $(echo -n 'client_xxx:secret_xxx' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "scope=read:data write:results"
```

Or with body parameters:

```bash
curl -X POST http://localhost:4000/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=client_xxx" \
  -d "client_secret=secret_xxx" \
  -d "scope=read:data write:results"
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `grant_type` | ✅ | Must be `client_credentials` |
| `client_id` | ✅ | OAuth2 client ID |
| `client_secret` | ✅ | OAuth2 client secret |
| `scope` | ❌ | Space-separated scopes (subset of client's allowed scopes) |

---

## Success Response

```json
{
  "access_token": "at_abc123def456...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "read:data write:results"
}
```

| Field | Description |
|---|---|
| `access_token` | Bearer token for API requests |
| `token_type` | Always `Bearer` |
| `expires_in` | Seconds until expiration (default: 3600) |
| `scope` | Granted scopes |

---

## Error Responses

```json
// Invalid client credentials
HTTP/1.1 401 Unauthorized
{ "error": "invalid_client", "error_description": "Client authentication failed" }

// Client deactivated
HTTP/1.1 401 Unauthorized
{ "error": "invalid_client", "error_description": "Client is not active" }

// Scopes not allowed for this client
HTTP/1.1 400 Bad Request
{ "error": "invalid_scope", "error_description": "The requested scope is invalid or exceeds the scope granted" }
```

---

## Using the Token

Include the access token in the `Authorization` header for authenticated API calls:

```bash
curl -H "Authorization: Bearer at_abc123def456..." \
  http://localhost:4000/api/users
```

---

## Python Example

```python
import httpx

THALAMUS_URL = "http://localhost:4000"
CLIENT_ID = "client_xxx"
CLIENT_SECRET = "secret_xxx"

# Get token
response = httpx.post(
    f"{THALAMUS_URL}/oauth/token",
    auth=(CLIENT_ID, CLIENT_SECRET),
    data={
        "grant_type": "client_credentials",
        "scope": "read:data write:results"
    }
)
response.raise_for_status()
token_data = response.json()
access_token = token_data["access_token"]

# Use token
response = httpx.get(
    f"{THALAMUS_URL}/api/users",
    headers={"Authorization": f"Bearer {access_token}"}
)
```

---

## Node.js Example

```javascript
const axios = require('axios');

async function getToken() {
  const params = new URLSearchParams();
  params.append('grant_type', 'client_credentials');
  params.append('scope', 'read:data write:results');

  const response = await axios.post(
    'http://localhost:4000/oauth/token',
    params,
    {
      auth: {
        username: process.env.CLIENT_ID,
        password: process.env.CLIENT_SECRET
      }
    }
  );

  return response.data.access_token;
}

// Usage
const token = await getToken();
const users = await axios.get('http://localhost:4000/api/users', {
  headers: { Authorization: `Bearer ${token}` }
});
```

---

## Token Properties

| Property | Value |
|---|---|
| Format | `at_` + random chars |
| TTL | 3600 seconds (1 hour) |
| Refresh token | Not issued |
| User ID | Not associated (M2M) |
| Organization | Bound to client's organization |

---

## See Also

- [OAuth2 Overview](overview.md) — All grants and endpoints
- [Authorization Code Flow](authorization-code.md) — User-facing flow
- [Token Introspection](token-introspection.md) — Validate tokens
