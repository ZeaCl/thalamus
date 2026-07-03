# Organizations API

Multi-tenant organization CRUD, member management, and SAML configuration.

---

## Endpoints

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| `GET` | `/api/organizations` | JWT | List organizations |
| `POST` | `/api/organizations` | JWT | Create organization |
| `GET` | `/api/organizations/:id` | JWT | Get organization |
| `PUT` | `/api/organizations/:id` | JWT | Update organization |
| `DELETE` | `/api/organizations/:id` | JWT | Delete organization |
| `POST` | `/api/organizations/:id/members` | JWT | Add member |
| `DELETE` | `/api/organizations/:id/members/:user_id` | JWT | Remove member |
| `GET` | `/api/organizations/:id/saml-config` | JWT/API Key | Get SAML config |
| `PUT` | `/api/organizations/:id/saml-config` | JWT/API Key | Update SAML config |
| `DELETE` | `/api/organizations/:id/saml-config` | JWT/API Key | Delete SAML config |

**Pipeline:** `authenticated_api` (JWT) for org CRUD and members. `api_auth` (JWT or API Key) for SAML config.

---

## List Organizations

```bash
GET /api/organizations?plan=enterprise&status=active
Authorization: Bearer eyJhbGciOi...
```

**Query Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `plan` | ❌ | Filter by plan type (`free`, `pro`, `enterprise`) |
| `status` | ❌ | `active` or `inactive` |
| `page` | ❌ | Page number |
| `per_page` | ❌ | Results per page |

**Response:**
```json
{
  "data": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440000",
      "name": "Acme Corp",
      "slug": "acme-corp",
      "plan": "enterprise",
      "status": "active",
      "members": [
        { "user_id": "user_abc123", "role": "admin" }
      ],
      "created_at": "2025-12-01T00:00:00Z"
    }
  ],
  "meta": { "total": 1, "page": 1, "per_page": 20 }
}
```

---

## Create Organization

```bash
POST /api/organizations
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "name": "Acme Corp",
  "plan": "enterprise"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `name` | ✅ | Organization name |
| `plan` | ❌ | `free`, `pro`, or `enterprise` |

**Response:** `201 Created` with organization object.

---

## Get Organization

```bash
GET /api/organizations/660e8400-e29b-41d4-a716-446655440000
Authorization: Bearer eyJhbGciOi...
```

**Response:** Organization object with members array.

---

## Update Organization

```bash
PUT /api/organizations/660e8400-e29b-41d4-a716-446655440000
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "name": "Acme Corp Updated",
  "plan": "pro",
  "status": "inactive"
}
```

**Updatable fields:** `name`, `plan` (`free`/`pro`/`enterprise`), `status` (`active`/`inactive`).

---

## Delete Organization

```bash
DELETE /api/organizations/660e8400-e29b-41d4-a716-446655440000
Authorization: Bearer eyJhbGciOi...
```

**Response:** `204 No Content`.

---

## Add Member

```bash
POST /api/organizations/org_abc123/members
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "email": "user@example.com",
  "role": "member"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `email` | ✅ | User email to add |
| `role` | ✅ | `admin` or `member` |

**Response:**
```json
{
  "data": {
    "user_id": "user_abc123",
    "role": "member",
    "organization_id": "org_abc123"
  }
}
```

---

## Remove Member

```bash
DELETE /api/organizations/org_abc123/members/user_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:** `200 OK`.

---

## SAML Configuration

### Get SAML Config

```bash
GET /api/organizations/org_abc123/saml-config
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": {
    "id": "saml_xyz",
    "entity_id": "https://acme.com/saml",
    "acs_url": "https://acme.com/saml/acs",
    "certificate": "-----BEGIN CERTIFICATE-----...",
    "enabled": true
  }
}
```

### Update SAML Config

```bash
PUT /api/organizations/org_abc123/saml-config
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "entity_id": "https://acme.com/saml",
  "acs_url": "https://acme.com/saml/acs",
  "certificate": "-----BEGIN CERTIFICATE-----...",
  "enabled": true
}
```

### Delete SAML Config

```bash
DELETE /api/organizations/org_abc123/saml-config
Authorization: Bearer eyJhbGciOi...
```

---

## See Also

- [Users API](users.md) — User management
- [Roles API](roles.md) — Role-based access control
- [SAML SSO Guide](../guides/saml-sso.md) — Full SAML setup
