# Personal Access Tokens API

Create, list, and revoke personal access tokens (PATs) for API authentication without OAuth2 flows. Ideal for CLI tools, scripts, and development.

---

## Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/personal-access-tokens` | List user's PATs |
| `POST` | `/api/personal-access-tokens` | Create PAT |
| `DELETE` | `/api/personal-access-tokens/:id` | Revoke PAT |

**Pipeline:** `authenticated_api` — JWT Bearer, 5000 req/min per user.

---

## List PATs

```bash
GET /api/personal-access-tokens
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": [
    {
      "id": "pat_abc123",
      "name": "CLI Token",
      "token_prefix": "th_pat_live_aB3x",
      "scopes": ["api:read", "api:write"],
      "organization_id": "org_abc123",
      "is_active": true,
      "expires_at": "2027-01-01T00:00:00Z",
      "last_used_at": "2026-06-15T10:30:00Z",
      "created_at": "2026-01-01T00:00:00Z"
    }
  ]
}
```

> The full token value is **never returned** after creation. Only the prefix is shown for identification.

---

## Create PAT

```bash
POST /api/personal-access-tokens
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "name": "CLI Token",
  "organization_id": "org_abc123",
  "scopes": ["api:read", "api:write"]
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `name` | ✅ | Descriptive name |
| `organization_id` | ✅ | Organization UUID |
| `scopes` | ❌ | Array of scopes (default: `["api:read", "api:write"]`) |

**Response:**
```json
{
  "data": {
    "id": "pat_abc123",
    "name": "CLI Token",
    "token": "th_pat_live_aB3xYz9...",
    "token_prefix": "th_pat_live_aB3x",
    "scopes": ["api:read", "api:write"],
    "expires_at": "2027-01-01T00:00:00Z",
    "created_at": "2026-01-01T00:00:00Z"
  }
}
```

> ⚠️ **The full `token` is only shown once.** Store it in a secure location.

### Using a PAT

```bash
curl -H "Authorization: Bearer th_pat_live_aB3xYz9..." \
  http://localhost:4000/api/users
```

---

## Revoke PAT

```bash
DELETE /api/personal-access-tokens/pat_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:** `204 No Content`. Token is immediately invalidated.

---

## Token Format

| Environment | Prefix |
|---|---|
| Development | `th_pat_dev_` |
| Production | `th_pat_live_` |

---

## See Also

- [Authentication API](authentication.md) — Login and registration
- [Admin API Keys](../guides/admin-api-keys.md) — Service-to-service keys
- [OAuth2 Overview](../oauth2/overview.md) — Full OAuth2 flows
