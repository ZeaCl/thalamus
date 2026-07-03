# Domains API

Domain-agnostic RBAC system. Register resource domains, grant/revoke scoped roles, and list domain assignments.

---

## Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/domains` | List registered domains |
| `POST` | `/api/domains/register` | Register a new domain |
| `POST` | `/api/domains/roles/grant` | Grant a domain role to a user |
| `DELETE` | `/api/domains/roles/revoke` | Revoke a domain role from a user |
| `GET` | `/api/domains/roles` | List domain-role assignments |

**Pipeline:** `authenticated_api` — JWT Bearer, 5000 req/min per user.

---

## List Domains

```bash
GET /api/domains
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": [
    {
      "id": "dom_abc123",
      "domain": "ventures",
      "scopes": ["venture:read", "venture:write", "venture:admin"],
      "created_at": "2026-01-01T00:00:00Z"
    }
  ]
}
```

---

## Register Domain

```bash
POST /api/domains/register
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "domain": "ventures",
  "scopes": ["venture:read", "venture:write", "venture:admin"]
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `domain` | ✅ | Domain name (resource prefix) |
| `scopes` | ✅ | Array of scopes in this domain |

**Response:** `201 Created` with domain object.

---

## Grant Domain Role

```bash
POST /api/domains/roles/grant
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "domain": "ventures",
  "user_id": "user_abc123",
  "scopes": ["venture:read", "venture:write"],
  "organization_id": "org_abc123"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `domain` | ✅ | Domain name |
| `user_id` | ✅ | User UUID |
| `scopes` | ✅ | Scopes to grant |
| `organization_id` | ✅ | Organization UUID |

**Response:**
```json
{
  "data": {
    "domain": "ventures",
    "user_id": "user_abc123",
    "scopes": ["venture:read", "venture:write"],
    "granted_at": "2026-01-15T10:00:00Z"
  }
}
```

---

## Revoke Domain Role

```bash
DELETE /api/domains/roles/revoke
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "domain": "ventures",
  "user_id": "user_abc123",
  "scopes": ["venture:write"]
}
```

**Response:** `200 OK`.

---

## List Domain Roles

```bash
GET /api/domains/roles?domain=ventures&user_id=user_abc123
Authorization: Bearer eyJhbGciOi...
```

**Query Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `domain` | ❌ | Filter by domain |
| `user_id` | ❌ | Filter by user |

**Response:**
```json
{
  "data": [
    {
      "domain": "ventures",
      "user_id": "user_abc123",
      "scopes": ["venture:read", "venture:write"],
      "granted_at": "2026-01-15T10:00:00Z"
    }
  ]
}
```

---

## See Also

- [Roles API](roles.md) — Global role management
- [Users API](users.md) — User management
- [Agent Skills](../agents/skills.md) — Domain scopes for agents
