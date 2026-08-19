# Users API

User CRUD, avatar management, and password change. Requires JWT Bearer authentication.

---

## Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/users` | List users |
| `POST` | `/api/users` | Create user |
| `GET` | `/api/users/:id` | Get user by ID |
| `PUT` | `/api/users/:id` | Update user |
| `DELETE` | `/api/users/:id` | Delete user |
| `PUT` | `/api/password/change` | Change own password |
| `POST` | `/api/avatar` | Upload avatar |
| `DELETE` | `/api/avatar` | Delete avatar |

**Pipeline:** `authenticated_api` — JWT Bearer required, 5000 req/min per user.

---

## List Users

```bash
GET /api/users?organization_id=org_abc&status=active&page=1&per_page=20
Authorization: Bearer eyJhbGciOi...
```

**Query Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `organization_id` | ❌ | Filter by organization |
| `status` | ❌ | `active` or `inactive` |
| `page` | ❌ | Page number (default: 1) |
| `per_page` | ❌ | Results per page (default: 20) |

**Response:**
```json
{
  "data": [
    {
      "id": "user_abc123",
      "email": "user@example.com",
      "status": "active",
      "verified_at": "2026-01-01T00:00:00Z",
      "created_at": "2025-12-01T00:00:00Z"
    }
  ],
  "meta": { "total": 1, "page": 1, "per_page": 20 }
}
```

---

## Get User

```bash
GET /api/users/user_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": {
    "id": "user_abc123",
    "email": "user@example.com",
    "status": "active",
    "verified_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-06-15T10:30:00Z"
  }
}
```

---

## Create User

```bash
POST /api/users
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "email": "newuser@example.com",
  "password": "SecurePass123!",
  "password_confirmation": "SecurePass123!",
  "organization_id": "org_abc123",
  "is_agent": false,
  "parent_user_id": "user_xyz789"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `email` | ✅ | Valid email |
| `password` | ✅ | Min 8 characters |
| `password_confirmation` | ✅ | Must match password |
| `organization_id` | ❌ | Assign to organization |
| `is_agent` | ❌ | `true` para crear un agente IA |
| `agent_config` | ❌ | Config del agente (ej. `{"role": "developer"}`) |
| `parent_user_id` | ❌ | Id del usuario padre en la jerarquía (`user_<uuid>`). Modela dependencia humano→agente o agente→sub-agente |

**Response:** `201 Created` with user object.

---

## Update User

```bash
PUT /api/users/user_abc123
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "email": "updated@example.com",
  "status": "inactive"
}
```

**Updatable fields:** `email`, `status` (`active` / `inactive`), `parent_user_id` (permite desvincular pasando `""` o ``null``).

**Response:** `200 OK` with updated user object.

---

## Delete User

```bash
DELETE /api/users/user_abc123
Authorization: Bearer eyJhbGciOi...
```

**Response:** `204 No Content`.

---

## Change Password

```bash
PUT /api/password/change
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "current_password": "OldPass123!",
  "password": "NewPass456!",
  "password_confirmation": "NewPass456!"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `current_password` | ✅ | Existing password |
| `password` | ✅ | New password |
| `password_confirmation` | ✅ | Must match new password |

**Response:** `200 OK`.

---

## Upload Avatar

```bash
POST /api/avatar
Authorization: Bearer eyJhbGciOi...
Content-Type: multipart/form-data

# file: avatar image (JPEG/PNG, max 5MB)
```

**Response:**
```json
{
  "data": {
    "avatar_url": "https://storage.zea.cl/avatars/user_abc123.jpg"
  }
}
```

---

## Delete Avatar

```bash
DELETE /api/avatar
Authorization: Bearer eyJhbGciOi...
```

**Response:** `200 OK`, avatar removed.

---

## Jerarquía Unificada de Usuarios

Todos los actores en Thalamus son `User` (humanos con `is_agent: false`, o agentes IA con `is_agent: true`).
El campo `parent_user_id` modela una estructura jerárquica donde cualquier usuario depende de otro:

```
        [CEO / Dirección (Humano)]
                 └──────────────┐
                         [Líder (Humano)]
                             ├── [Dev Junior (Humano)]
                             └── [dev_agent (Agente IA)]
                                   └── [sub_agent (Agente)]
```

**query eficiente del árbol:**

- `find_by_parent/1` — hijos directos (`parent_user_id = user.id`).
- `find_tree/1,2` — sub-árbol completo (descendientes directos e indirectos), con filtro opcional por organización.
- `find_agents_subtree/1` — solo los agentes IA subordinados disponibles para delegar tareas.

### `reports` en `/oauth/userinfo`

Cuando un usuario hace login, `GET /oauth/userinfo` incluye sus dependientes (usuarios/agentes con `parent_user_id = current_user.id`):

```json
{
  "sub": "c0000001-0000-0000-0000-000000000001",
  "email": "alice@acme.corp",
  "name": "Alice Smith",
  "reports": [
    {
      "id": "user_d7b8a0f3-0000-0000-0000-000000000002",
      "name": "Acme Dev Copilot",
      "email": "dev_agent@acme.corp",
      "is_agent": true,
      "role": "developer"
    }
  ]
}
```

Si el usuario no tiene dependientes, `reports` será un arreglo vacío `[]`.

---

## See Also

- [Authentication API](authentication.md) — Login and registration (no auth)
- [Organizations API](organizations.md) — Organization management
- [Roles API](roles.md) — Role-based access control
