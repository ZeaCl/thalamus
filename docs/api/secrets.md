# Secrets API

Manage encrypted secrets for OAuth2 clients and services. Internal resolve endpoint for microservices.

---

## Endpoints

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| `GET` | `/api/secrets` | JWT/API Key | List secrets |
| `POST` | `/api/secrets` | JWT/API Key | Create secret |
| `DELETE` | `/api/secrets/:id` | JWT/API Key | Delete secret |
| `GET` | `/api/internal/secrets/resolve` | None (internal) | Resolve secret by provider |

**Pipelines:** `api_auth` for CRUD, `internal_api` for resolve.

---

## List Secrets

```bash
GET /api/secrets?owner_type=oauth2_client&owner_id=client_abc123
Authorization: Bearer eyJhbGciOi...
```

**Query Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `owner_type` | ✅ | `oauth2_client` or `organization` |
| `owner_id` | ✅ | Owner UUID |

**Response:**
```json
{
  "data": [
    {
      "id": "sec_abc123",
      "provider": "aws",
      "owner_type": "oauth2_client",
      "owner_id": "client_abc123",
      "created_at": "2026-01-01T00:00:00Z"
    }
  ]
}
```

---

## Create Secret

```bash
POST /api/secrets
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "secret": {
    "provider": "aws",
    "key": "AWS_ACCESS_KEY_ID",
    "value": "AKIAIOSFODNN7EXAMPLE",
    "owner_type": "oauth2_client",
    "owner_id": "client_abc123"
  }
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `provider` | ✅ | Service provider (e.g., `aws`, `openai`, `github`) |
| `key` | ✅ | Secret key name |
| `value` | ✅ | Secret value (encrypted at rest) |
| `owner_type` | ✅ | `oauth2_client` or `organization` |
| `owner_id` | ✅ | Owner UUID |

**Response:** `201 Created` with secret metadata (value is never returned).

---

## Delete Secret

```bash
DELETE /api/secrets/sec_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:** `204 No Content`.

---

## Resolve Secret (Internal)

Used by microservices to retrieve a secret value by provider at runtime.

```bash
GET /api/internal/secrets/resolve?provider=aws&owner_type=oauth2_client&owner_id=client_abc123&key=AWS_ACCESS_KEY_ID
```

**Query Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `provider` | ✅ | Service provider |
| `owner_type` | ✅ | `oauth2_client` or `organization` |
| `owner_id` | ✅ | Owner UUID |
| `key` | ✅ | Secret key name |

**Response:**
```json
{
  "data": {
    "provider": "aws",
    "key": "AWS_ACCESS_KEY_ID",
    "value": "AKIAIOSFODNN7EXAMPLE"
  }
}
```

> Internal endpoint, no auth for intra-network calls. In production, protected by mTLS.

---

## See Also

- [Clients API](clients.md) — OAuth2 client management
- [Organizations API](organizations.md) — Organization management
