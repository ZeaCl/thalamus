# OAuth2 Clients API

Manage OAuth2 client applications, secret rotation, redirect URI management, and client diagnostics.

---

## Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/clients` | List clients |
| `POST` | `/api/clients` | Create client |
| `GET` | `/api/clients/:id` | Get client |
| `PUT` | `/api/clients/:id` | Update client |
| `DELETE` | `/api/clients/:id` | Delete client |
| `POST` | `/api/clients/:client_id/rotate-secret` | Rotate client secret |
| `POST` | `/api/clients/:client_id/add-redirect-uri` | Add dynamic redirect URI |
| `GET` | `/api/clients/:client_id/validate` | Validate client configuration |

**Pipeline:** `api_auth` — JWT Bearer or API Key. 5000 req/min per user.

---

## List Clients

```bash
GET /api/clients?organization_id=org_abc&status=active
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": [
    {
      "id": "client_abc123",
      "name": "My App",
      "client_id": "client_abc123",
      "client_type": "confidential",
      "redirect_uris": ["https://app.com/callback"],
      "grant_types": ["authorization_code", "refresh_token"],
      "allowed_scopes": ["openid", "profile", "email"],
      "is_active": true,
      "organization_id": "org_abc123",
      "created_at": "2026-01-01T00:00:00Z"
    }
  ],
  "meta": { "total": 1, "page": 1, "per_page": 20 }
}
```

---

## Create Client

```bash
POST /api/clients
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "name": "My App",
  "organization_id": "org_abc123",
  "client_type": "confidential",
  "redirect_uris": ["https://app.com/callback"],
  "grant_types": ["authorization_code", "refresh_token"],
  "scopes": ["openid", "profile", "email"]
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `name` | ✅ | Client display name |
| `organization_id` | ✅ | Organization UUID |
| `client_type` | ✅ | `confidential` or `public` |
| `redirect_uris` | ✅ | Array of redirect URIs |
| `grant_types` | ✅ | Array: `authorization_code`, `client_credentials`, `refresh_token` |
| `scopes` | ✅ | Array of allowed scopes |

**Response:** `201 Created`.

```json
{
  "data": {
    "id": "client_abc123",
    "client_id": "client_abc123",
    "client_secret": "secret_xyz789",
    "name": "My App",
    "client_type": "confidential",
    "redirect_uris": ["https://app.com/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "allowed_scopes": ["openid", "profile", "email"],
    "is_active": true,
    "created_at": "2026-01-01T00:00:00Z"
  }
}
```

> ⚠️ **The `client_secret` is only returned once** during creation. Store it securely.

---

## Get Client

```bash
GET /api/clients/client_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:** Client object (without secret).

---

## Update Client

```bash
PUT /api/clients/client_abc123
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "name": "My Updated App",
  "redirect_uris": ["https://app.com/callback", "https://staging.app.com/callback"],
  "scopes": ["openid", "profile", "email", "offline_access"],
  "is_active": false
}
```

**Updatable fields:** `name`, `redirect_uris`, `scopes`, `is_active`.

---

## Delete Client

```bash
DELETE /api/clients/client_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:** `204 No Content`.

---

## Rotate Client Secret

Generates a new secret and invalidates the previous one.

```bash
POST /api/clients/client_abc123/rotate-secret
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": {
    "client_id": "client_abc123",
    "client_secret": "secret_new789",
    "message": "Secret rotated successfully"
  }
}
```

> ⚠️ Old secret is immediately invalidated. Update all services using the old secret.

---

## Add Redirect URI

Add a dynamic redirect URI for subdomain support.

```bash
POST /api/clients/client_abc123/add-redirect-uri
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "redirect_uri": "https://custom.app.com/callback"
}
```

**Response:** `200 OK` with updated redirect URIs list.

---

## Validate Client

Diagnostic endpoint to check client configuration.

```bash
GET /api/clients/client_abc123/validate
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": {
    "valid": true,
    "issues": [],
    "checks": {
      "redirect_uris_valid": true,
      "scopes_valid": true,
      "grant_types_valid": true,
      "secret_not_expired": true
    }
  }
}
```

---

## See Also

- [Admin API Keys](../guides/admin-api-keys.md) — Auto-register clients with API keys
- [OAuth2 Overview](../oauth2/overview.md) — Grant types and flows
- [Roles API](roles.md) — Scope management via roles
