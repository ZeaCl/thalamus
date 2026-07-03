# UserInfo Endpoint (OpenID Connect)

Returns information about the authenticated user. Requires a valid Bearer access token.

---

## Endpoint

```
GET /oauth/userinfo
Authorization: Bearer at_abc123...
```

---

## Request

```bash
curl -H "Authorization: Bearer at_abc123def456..." \
  http://localhost:4000/oauth/userinfo
```

No query parameters or body required. The token is extracted from the `Authorization: Bearer` header.

---

## Success Response

```json
{
  "sub": "user_abc123",
  "email": "user@example.com",
  "email_verified": true,
  "updated_at": 1640995200,
  "organization": {
    "id": "660e8400-e29b-41d4-a716-446655440000",
    "name": "Acme Corp",
    "slug": "acme-corp"
  },
  "organizations": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440000",
      "name": "Acme Corp",
      "slug": "acme-corp"
    },
    {
      "id": "770e8400-e29b-41d4-a716-446655440001",
      "name": "Other Org",
      "slug": "other-org"
    }
  ]
}
```

### Response Fields

| Field | Type | Description |
|---|---|---|
| `sub` | string | Subject identifier (user UUID) |
| `email` | string | User's email address |
| `email_verified` | boolean | Whether the email has been verified |
| `updated_at` | number | Last update timestamp (Unix seconds) |
| `organization` | object | User's primary organization |
| `organization.id` | string | Organization UUID |
| `organization.name` | string | Organization display name |
| `organization.slug` | string | URL-safe slug |
| `organizations` | array | All organizations the user belongs to |

---

## Error Responses

### Invalid or Expired Token

```json
HTTP/1.1 401 Unauthorized

{
  "error": "invalid_token",
  "error_description": "Invalid or expired token"
}
```

### Missing Authorization Header

```json
HTTP/1.1 401 Unauthorized

{
  "error": "invalid_token",
  "error_description": "Could not validate access token"
}
```

---

## Token Validation Flow

The UserInfo endpoint performs these validations:

1. **Extracts Bearer token** from the `Authorization` header
2. **Validates token** via `ValidateToken` use case:
   - Checks token format and signature
   - Verifies token exists in database
   - Checks token hasn't expired
   - Confirms token hasn't been revoked
3. **Fetches user** from the repository
4. **Fetches user schema** for primary organization
5. **Fetches all organizations** where the user is a member

---

## Python Example

```python
import httpx

def get_userinfo(access_token: str) -> dict:
    response = httpx.get(
        "http://localhost:4000/oauth/userinfo",
        headers={"Authorization": f"Bearer {access_token}"}
    )

    if response.status_code == 401:
        raise Exception("Token is invalid or expired")

    response.raise_for_status()
    userinfo = response.json()

    print(f"User: {userinfo['email']}")
    print(f"Organization: {userinfo['organization']['name']}")
    print(f"Member of {len(userinfo['organizations'])} organization(s)")

    return userinfo
```

---

## Node.js Example

```javascript
async function getUserInfo(accessToken) {
  const response = await fetch('http://localhost:4000/oauth/userinfo', {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });

  if (response.status === 401) {
    throw new Error('Token is invalid or expired');
  }

  const userinfo = await response.json();

  console.log(`User: ${userinfo.email}`);
  console.log(`Organization: ${userinfo.organization.name}`);
  console.log(`Organizations: ${userinfo.organizations.length}`);

  return userinfo;
}
```

---

## See Also

- [OAuth2 Overview](overview.md) — All grants and endpoints
- [Authorization Code Flow](authorization-code.md) — How to get a token
- [Token Introspection](token-introspection.md) — Validate tokens
- [Discovery & JWKS](discovery.md) — OIDC Discovery metadata
