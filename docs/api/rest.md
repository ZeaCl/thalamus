# REST API Reference

Thalamus exposes a REST API for user management, organization administration, OAuth2 client management, RBAC, and more.

---

## Base URL

| Environment | URL |
|---|---|
| ZEA Cloud | `https://auth.zea.cl` |
| On-Premise | `http://localhost:4000` |

---

## Authentication

### Bearer Token (JWT)

For endpoints requiring user authentication:

```bash
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

Obtained via OAuth2 flows ([Authorization Code](../oauth2/authorization-code.md), [Client Credentials](../oauth2/client-credentials.md)) or `POST /api/public/login`.

### API Key (Admin / Service)

For service-to-service endpoints:

```bash
Authorization: ApiKey ak_dev_vK8mN2pQ7xR9...
```

See [Admin API Keys](../guides/admin-api-keys.md).

---

## Pipelines & Rate Limiting

| Pipeline | Auth Required | Rate Limit | Used By |
|---|---|---|---|
| `api` | None | 1000 req/min per IP | `/api/public/*`, `/.well-known/*` |
| `oauth2_api` | None | 1000 req/min per IP | `/oauth/token`, `/oauth/introspect`, `/oauth/revoke` |
| `oauth2_browser` | Session | 20 req/min per IP | `/oauth/authorize` |
| `authenticated_api` | JWT Bearer | 5000 req/min per user | `/api/*` (user-scoped) |
| `api_auth` | JWT or API Key | 5000 req/min per user | `/api/clients`, `/api/secrets` |
| `super_admin` | JWT + super_admin role | 1000 req/min per user | `/api/admin/*` |
| `internal_api` | None (intra-network) | None | `/api/internal/*` |

---

## Response Format

### Success (Single Resource)

```json
{
  "data": {
    "id": "user_abc123",
    "email": "user@example.com",
    ...
  }
}
```

### Success (Collection)

```json
{
  "data": [
    { "id": "user_abc123", ... },
    { "id": "user_def456", ... }
  ],
  "meta": {
    "total": 42,
    "page": 1,
    "per_page": 20
  }
}
```

### Error

```json
{
  "error": "invalid_request",
  "message": "Email already registered"
}
```

### OAuth2 Error (RFC 6749 §5.2)

```json
{
  "error": "invalid_grant",
  "error_description": "PKCE verification failed"
}
```

---

## Common Headers

| Header | Value |
|---|---|
| `Content-Type` | `application/json` or `application/x-www-form-urlencoded` |
| `Authorization` | `Bearer <token>` or `ApiKey <key>` or `Basic base64(client:secret)` |
| `Accept` | `application/json` |

---

## API Sections

| Section | Endpoints | Auth |
|---|---|---|
| [Authentication](authentication.md) | Login, register, email, password | None |
| [Users](users.md) | CRUD, avatar, password change | JWT |
| [Organizations](organizations.md) | CRUD, members, SAML config | JWT / API Key |
| [Clients](clients.md) | CRUD OAuth2 clients, secret rotation | JWT / API Key |
| [Roles](roles.md) | CRUD roles, user assignments, effective scopes | JWT |
| [MFA](mfa.md) | TOTP setup, verify, disable, backup codes | JWT |
| [Secrets](secrets.md) | CRUD secrets, internal resolve | JWT / API Key / Internal |
| [Domains](domains.md) | Domain-agnostic RBAC | JWT |
| [Personal Access Tokens](personal-access-tokens.md) | CRUD PATs | JWT |
| [Audit Logs](audit-logs.md) | Export CSV/JSON | JWT |
