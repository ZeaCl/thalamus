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
  "organization_id": "org_abc123"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `email` | ✅ | Valid email |
| `password` | ✅ | Min 8 characters |
| `password_confirmation` | ✅ | Must match password |
| `organization_id` | ❌ | Assign to organization |

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

**Updatable fields:** `email`, `status` (`active` / `inactive`).

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

## See Also

- [Authentication API](authentication.md) — Login and registration (no auth)
- [Organizations API](organizations.md) — Organization management
- [Roles API](roles.md) — Role-based access control
