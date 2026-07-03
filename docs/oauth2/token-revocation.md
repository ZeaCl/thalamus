# Token Revocation (RFC 7009)

Revoke an access token or refresh token. After revocation, the token can no longer be used for API calls or token refresh.

---

## Endpoint

```
POST /oauth/revoke
Content-Type: application/x-www-form-urlencoded
```

---

## Request

### Using HTTP Basic Auth (Recommended)

```bash
curl -X POST http://localhost:4000/oauth/revoke \
  -H "Authorization: Basic $(echo -n 'client_xxx:secret_xxx' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=at_abc123def456..." \
  -d "token_type_hint=access_token"
```

### Using Body Parameters

```bash
curl -X POST http://localhost:4000/oauth/revoke \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=at_abc123def456..." \
  -d "token_type_hint=access_token" \
  -d "client_id=client_xxx" \
  -d "client_secret=secret_xxx"
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `token` | ✅ | The token to revoke |
| `token_type_hint` | ❌ | Hint: `access_token` or `refresh_token` |

**Authentication:** Client must authenticate via HTTP Basic Auth or body parameters.

---

## Response

```
HTTP/1.1 200 OK
Cache-Control: no-store
Pragma: no-cache

{}
```

> **Per RFC 7009 §2.2, the server always responds with 200 OK**, regardless of whether the token was valid, already revoked, or never existed. This prevents information leakage about token validity.

---

## Error Responses

### Missing Token

```json
HTTP/1.1 400 Bad Request

{
  "error": "invalid_request",
  "error_description": "Missing required parameter: token"
}
```

### Client Authentication Failed

```json
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Basic

{
  "error": "invalid_client",
  "error_description": "Client authentication failed"
}
```

### Missing Credentials

```json
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Basic

{
  "error": "invalid_client",
  "error_description": "Client credentials required"
}
```

---

## Client Authentication

The revocation endpoint requires client authentication. Two methods are supported:

### 1. HTTP Basic Auth

```
Authorization: Basic base64(client_id:client_secret)
```

### 2. Body Parameters

```
client_id=client_xxx&client_secret=secret_xxx
```

---

## Python Example

```python
import httpx

def revoke_token(token: str, client_id: str, client_secret: str):
    response = httpx.post(
        "http://localhost:4000/oauth/revoke",
        auth=(client_id, client_secret),
        data={
            "token": token,
            "token_type_hint": "access_token"
        }
    )
    response.raise_for_status()
    print("Token revoked (or was already invalid)")
```

---

## Node.js Example

```javascript
async function revokeToken(token, clientId, clientSecret) {
  const params = new URLSearchParams();
  params.append('token', token);
  params.append('token_type_hint', 'access_token');

  const response = await fetch('http://localhost:4000/oauth/revoke', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64')
    },
    body: params
  });

  // 200 OK = revocation successful (or token was already invalid)
  console.log(`Revocation status: ${response.status}`);
}
```

---

## What Gets Revoked

The `token_type_hint` helps the server find the token faster:

| Hint | Looks for |
|---|---|
| `access_token` | Searches access tokens first |
| `refresh_token` | Searches refresh tokens first |
| (omitted) | Searches both types |

Regardless of the hint, the server attempts to revoke any matching token.

---

## See Also

- [OAuth2 Overview](overview.md) — All grants and endpoints
- [Token Introspection](token-introspection.md) — Validate tokens (RFC 7662)
- [Authorization Code Flow](authorization-code.md) — Get tokens
