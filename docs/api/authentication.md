# Authentication API

Endpoints for user login, registration, email verification, and password reset. No authentication required.

---

## Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/api/public/login` | Authenticate with email + password |
| `POST` | `/api/public/register` | Create new user account |
| `POST` | `/api/public/verify-email` | Verify email with token |
| `POST` | `/api/public/resend-verification` | Resend verification email |
| `POST` | `/api/public/password/reset` | Request password reset |
| `POST` | `/api/public/password/confirm-reset` | Confirm reset with token |

---

## Login

```
POST /api/public/login
Content-Type: application/json
```

```bash
curl -X POST http://localhost:4000/api/public/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!"
  }'
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `email` | ✅ | User email |
| `password` | ✅ | User password |

**Success Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "user": {
    "id": "user_abc123",
    "email": "user@example.com",
    "name": "User Name",
    "verified": true
  }
}
```

### JWT Claims

El `access_token` es un JWT firmado con RS256. Al decodificarlo, incluye los siguientes claims:

```json
{
  "iss": "https://auth.zea.cl",
  "aud": "zea",
  "iat": 1752050000,
  "exp": 1752053600,
  "jti": "jti_abc123...",
  "sub": "user_c0000000-852c-44e5-aee1-a761ec76eaea",
  "scope": "openid profile email",
  "client_id": "thalamus_api",
  "name": "User Name",
  "email": "user@example.com",
  "is_agent": false,
  "scopes": ["funds:read", "funds:write"],
  "domain_roles": [
    {
      "org_id": "ea7b11ea-852c-44e5-aee1-a761ec76eaea",
      "domain": "funds",
      "role": "gp_admin",
      "scopes": ["funds:read", "funds:write"]
    }
  ],
  "authz_source": "domain_roles"
}
```

| Claim | Tipo | Descripción |
|---|---|---|
| `sub` | string | User ID con prefijo `user_` |
| `scope` | string | Scopes OAuth2 solicitados (space-separated) |
| `scopes` | string[] | **Todos** los scopes del usuario (union de todos sus domain_roles) |
| `domain_roles` | object[] | **Siempre presente** (array vacío `[]` si el usuario no tiene roles). Claim principal para autorización multi-tenant. Cada entry tiene `org_id`, `domain`, `role`, `scopes`, y opcionalmente `entity_id` |
| `authz_source` | string | Siempre `"domain_roles"`. Indica que `domain_roles` es la fuente canónica de autorización |
| `is_agent` | boolean | `true` si el usuario es un agente AI |
| `organization_id` | string | ⚠️ **Deprecated**. Usar `domain_roles[].org_id` en su lugar. Se mantiene por compatibilidad con integraciones viejas |

> ⚠️ **Importante para integradores**: Los servicios downstream (fm_funds, cerebelum, etc.) deben leer los permisos desde `domain_roles`, **no** desde `scope` ni `organization_id`. El claim `domain_roles` y `authz_source` son las fuentes canónicas de autorización multi-tenant.

**Error Responses:**

| Status | Code | When |
|---|---|---|
| `401` | `invalid_credentials` | Wrong email or password |
| `401` | `account_locked` | Too many failed attempts |
| `401` | `account_suspended` | Account is suspended |
| `401` | `account_not_verified` | Email not verified |
| `400` | `missing_parameter` | Email or password missing |

---

## Register

```
POST /api/public/register
Content-Type: application/json
```

```bash
curl -X POST http://localhost:4000/api/public/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!",
    "password_confirmation": "SecurePass123!",
    "organization_name": "Acme Corp"
  }'
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `email` | ✅ | Valid email address |
| `password` | ✅ | Password (min 8 chars) |
| `password_confirmation` | ✅ | Must match password |
| `organization_name` | ❌ | Create an organization on registration |

**Success Response:**
```json
{
  "data": {
    "id": "user_abc123",
    "email": "user@example.com",
    "verified_at": null,
    "created_at": "2026-01-01T00:00:00Z"
  }
}
```

**Error Responses:**

| Status | Code | When |
|---|---|---|
| `400` | `email_taken` | Email already registered |
| `400` | `password_mismatch` | Passwords don't match |
| `400` | `invalid_email` | Email format invalid |

---

## Verify Email

```
POST /api/public/verify-email
Content-Type: application/json
```

```bash
curl -X POST http://localhost:4000/api/public/verify-email \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_abc123",
    "token": "verification_token_xyz"
  }'
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `user_id` | ✅ | User UUID |
| `token` | ✅ | Verification token from email |

**Success Response:**
```json
{
  "data": {
    "verified": true,
    "message": "Email verified successfully"
  }
}
```

---

## Resend Verification

```
POST /api/public/resend-verification
Content-Type: application/json
```

```bash
curl -X POST http://localhost:4000/api/public/resend-verification \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `email` | ✅ | Registered email address |

**Response:** `200 OK` (always, prevents email enumeration)

---

## Password Reset Request

```
POST /api/public/password/reset
Content-Type: application/json
```

```bash
curl -X POST http://localhost:4000/api/public/password/reset \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `email` | ✅ | Registered email address |

**Response:** `200 OK` with reset token (in dev) or email sent (in prod).

```json
{
  "data": {
    "token": "reset_token_abc123",
    "message": "Password reset email sent"
  }
}
```

---

## Confirm Password Reset

```
POST /api/public/password/confirm-reset
Content-Type: application/json
```

```bash
curl -X POST http://localhost:4000/api/public/password/confirm-reset \
  -H "Content-Type: application/json" \
  -d '{
    "token": "reset_token_abc123",
    "password": "NewSecurePass456!",
    "password_confirmation": "NewSecurePass456!"
  }'
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `token` | ✅ | Reset token from email |
| `password` | ✅ | New password |
| `password_confirmation` | ✅ | Must match password |

**Success Response:**
```json
{
  "data": {
    "token": "new_auth_token",
    "message": "Password reset successfully"
  }
}
```

---

## See Also

- [Domains API](domains.md) — Domain-role assignment (RBAC multi-tenant)
- [Users API](users.md) — User CRUD (authenticated)
- [MFA API](mfa.md) — Multi-factor authentication
- [OAuth2 Authorization Code](../oauth2/authorization-code.md) — Full OAuth2 login flow
