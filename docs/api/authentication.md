# Authentication API

Endpoints for user registration, email verification, and password reset. No authentication required.

> **Note:** user **login** is handled by the standard OAuth2 flows (see [OAuth2 overview](../oauth2/overview.md) and [Authorization Code + PKCE](../oauth2/authorization-code.md)), not by a dedicated endpoint here.

---

## Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/api/public/register` | Create new user account |
| `POST` | `/api/public/verify-email` | Verify email with token |
| `POST` | `/api/public/resend-verification` | Resend verification email |
| `POST` | `/api/public/password/reset` | Request password reset |
| `POST` | `/api/public/password/confirm-reset` | Confirm reset with token |

---

## JWT Claims

All access tokens issued by Thalamus are RS256-signed JWTs produced by `JwtSigner.sign_access_token/1`. Decoded, they include:

```json
{
  "iss": "https://auth.zea.cl",
  "aud": "zea",
  "iat": 1752050000,
  "exp": 1752053600,
  "jti": "jti_abc123...",
  "sub": "user_c0000000-852c-44e5-aee1-a761ec76eaea",
  "scope": "openid profile email",
  "client_id": "thalamus_cli",
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

| Claim | Type | Description |
|---|---|---|
| `sub` | string | User ID with `user_` prefix |
| `scope` | string | Requested OAuth2 scopes (space-separated) |
| `scopes` | string[] | **All** user scopes (union of all their domain_roles) |
| `domain_roles` | object[] | **Always present** (empty array `[]` if the user has no roles). Primary claim for multi-tenant authorization. Each entry has `org_id`, `domain`, `role`, `scopes`, and optionally `entity_id` |
| `authz_source` | string | Always `"domain_roles"`. Marks `domain_roles` as the canonical authorization source |
| `is_agent` | boolean | `true` if the user is an AI agent |
| `organization_id` | string | ⚠️ **Deprecated**. Use `domain_roles[].org_id` instead. Kept for compatibility with legacy integrations |

> ⚠️ **Important for integrators**: downstream services (fm_funds, cerebelum, etc.) must read permissions from `domain_roles`, **not** from `scope` or `organization_id`. The `domain_roles` and `authz_source` claims are the canonical sources for multi-tenant authorization.

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
