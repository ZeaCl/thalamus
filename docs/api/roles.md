# Roles API (RBAC)

Role-based access control: create roles with scopes, assign them to users, and compute effective permissions.

---

## Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/roles` | List roles |
| `POST` | `/api/roles` | Create role |
| `GET` | `/api/roles/:id` | Get role |
| `PUT` | `/api/roles/:id` | Update role scopes |
| `DELETE` | `/api/roles/:id` | Delete role |
| `POST` | `/api/users/:user_id/roles` | Assign role to user |
| `DELETE` | `/api/users/:user_id/roles/:role_id` | Revoke role from user |
| `GET` | `/api/users/:user_id/roles` | List user's roles |
| `GET` | `/api/users/:user_id/effective-scopes` | Compute effective scopes |

**Pipeline:** `authenticated_api` — JWT Bearer, 5000 req/min per user.

---

## List Roles

```bash
GET /api/roles?organization_id=org_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": [
    {
      "id": "role_abc123",
      "name": "Data Analyst",
      "description": "Read-only access to data",
      "scopes": ["data:read", "report:view"],
      "organization_id": "org_abc123",
      "created_at": "2026-01-01T00:00:00Z"
    }
  ]
}
```

---

## Create Role

```bash
POST /api/roles
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "name": "Data Analyst",
  "description": "Read-only access to data resources",
  "scopes": ["data:read", "report:view"],
  "organization_id": "org_abc123"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `name` | ✅ | Role name |
| `description` | ❌ | Role description |
| `scopes` | ✅ | Array of scope strings |
| `organization_id` | ✅ | Organization UUID |

**Response:** `201 Created` with role object.

---

## Get Role

```bash
GET /api/roles/role_abc123
Authorization: Bearer eyJhbGciOi...
```

---

## Update Role

```bash
PUT /api/roles/role_abc123
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "scopes": ["data:read", "data:write", "report:view", "report:generate"]
}
```

**Updatable field:** `scopes` (replaces existing scopes).

---

## Delete Role

```bash
DELETE /api/roles/role_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:** `204 No Content`.

---

## Assign Role to User

```bash
POST /api/users/user_abc123/roles
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "role_id": "role_abc123"
}
```

**Response:**
```json
{
  "data": {
    "user_id": "user_abc123",
    "role_id": "role_abc123",
    "role_name": "Data Analyst"
  }
}
```

---

## Revoke Role from User

```bash
DELETE /api/users/user_abc123/roles/role_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:** `200 OK`.

---

## List User's Roles

```bash
GET /api/users/user_abc123/roles
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": [
    {
      "role_id": "role_abc123",
      "role_name": "Data Analyst",
      "scopes": ["data:read", "report:view"],
      "assigned_at": "2026-01-15T10:00:00Z"
    }
  ]
}
```

---

## Get Effective Scopes

Computes the union of all scopes from all roles assigned to a user.

```bash
GET /api/users/user_abc123/effective-scopes
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": {
    "user_id": "user_abc123",
    "effective_scopes": [
      "data:read",
      "data:write",
      "report:view",
      "report:generate"
    ],
    "source_roles": [
      { "role_id": "role_abc123", "scopes": ["data:read", "report:view"] },
      { "role_id": "role_def456", "scopes": ["data:write", "report:generate"] }
    ]
  }
}
```

---

## See Also

- [Users API](users.md) — User management
- [Agent Skills](../agents/skills.md) — Scopes for AI agents
- [OpenAPI Spec](../OPENAPI_SPEC.yaml) — Full API specification
