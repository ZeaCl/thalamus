# OAuth2 Overview

Thalamus implements OAuth 2.0 (RFC 6749) with PKCE (RFC 7636), token introspection (RFC 7662), and revocation (RFC 7009).

---

## Supported Grant Types

| Grant Type | Use Case | User Required | PKCE Required | Refresh Token |
|---|---|---|---|---|
| `authorization_code` | Web apps, mobile apps | ✅ Yes | ✅ Yes (S256) | ✅ Yes |
| `client_credentials` | Machine-to-machine (M2M) | ❌ No | ❌ No | ❌ No |
| `refresh_token` | Token renewal | — | ❌ No | ✅ Yes (rotation) |
| `password` | **Deprecated** — Legacy only | ✅ Yes | ❌ No | — |

> **Implicit grant is intentionally NOT supported** for security reasons.

---

## Endpoints

| Method | Endpoint | Purpose | RFC |
|---|---|---|---|
| `GET` | `/oauth/authorize` | Authorization screen (user consent) | 6749 §3.1 |
| `POST` | `/oauth/authorize` | Process consent decision | 6749 §3.1 |
| `POST` | `/oauth/token` | Exchange code/credentials for tokens | 6749 §3.2 |
| `POST` | `/oauth/agent-token` | Agent-specific tokens with task-scoping | — |
| `GET` | `/oauth/userinfo` | OpenID Connect user info | OIDC |
| `POST` | `/oauth/introspect` | Validate token state/metadata | 7662 |
| `POST` | `/oauth/revoke` | Revoke a token | 7009 |
| `GET` | `/.well-known/openid-configuration` | OIDC Discovery metadata | OIDC Discovery |
| `GET` | `/.well-known/jwks.json` | Public keys for JWT verification | JWKS |

---

## PKCE (Proof Key for Code Exchange)

PKCE is **required** for the authorization code flow. Thalamus supports:

| Method | Description | Recommended |
|---|---|---|
| `S256` | SHA256 hash of code verifier | ✅ Yes |
| `plain` | Plain text (not recommended) | ❌ No |

**Flow:**
1. Client generates a `code_verifier` (random string, 43-128 chars)
2. Client computes `code_challenge = BASE64URL(SHA256(code_verifier))`
3. Client sends `code_challenge` + `code_challenge_method=S256` to `/oauth/authorize`
4. Client sends `code_verifier` to `/oauth/token`

---

## Scopes

### Standard OIDC Scopes

| Scope | Description |
|---|---|
| `openid` | Basic profile information |
| `profile` | Profile details (name, picture) |
| `email` | Email address |
| `address` | Physical address |
| `phone` | Phone number |
| `offline_access` | Refresh token issuance |

### ZEA Platform Scopes

| Scope | Description |
|---|---|
| `zea:read` | Read access to ZEA resources |
| `zea:write` | Write access to ZEA resources |
| `zea:admin` | Administrative access |
| `synapse:events` | Access to event streams |
| `cortex:chat` | Access to chat/LLM features |
| `billing:read` | Read billing data |
| `organizations:write` | Organization management |

---

## Client Authentication

Thalamus supports two methods for client authentication:

### 1. HTTP Basic Auth (Recommended)

```bash
Authorization: Basic base64(client_id:client_secret)
```

### 2. Request Body Parameters

```bash
client_id=client_xxx&client_secret=secret_xxx
```

---

## Token Lifecycle

```
┌──────────────┐     code      ┌──────────────┐
│  /authorize  │ ────────────→ │   /token     │
│  (GET/POST)  │               │   (POST)     │
└──────────────┘               └──────┬───────┘
                                      │
                         ┌────────────┼────────────┐
                         ▼            ▼            ▼
                   access_token  refresh_token  id_token
                    (1h TTL)     (30d TTL)     (JWT)
                         │            │
                         │     ┌──────▼───────┐
                         │     │   /token     │
                         │     │ refresh_token│
                         │     └──────────────┘
                         ▼
              ┌─────────────────────┐
              │  /introspect (POST) │ ← Validate
              │  /revoke     (POST) │ ← Revoke
              │  /userinfo   (GET)  │ ← User data
              └─────────────────────┘
```

---

## First-Party Client Auto-Approval

Trusted clients (those with `auto_approve = true` in the database) **bypass the consent screen** and auto-approve authorization requests. This is managed via the `auto_approve` column on `oauth2_clients` — no hardcoded lists.

### Bootstrap Client Pattern

`thalamus_cli` is the **bootstrap client** — a shared OAuth2 client used by CLI tools and other ZEA ecosystem apps to authenticate developers. It is a public client (no secret) with PKCE required.

**Clients that use `thalamus_cli`:**
- `npx zea-auth-init` — logs in a developer and registers a new OAuth2 app
- `cerebelum login` — logs in a developer and stores a JWT for API access

**When to use `thalamus_cli` vs. registering your own client:**

| Scenario | Use |
|---|---|
| CLI tool that needs to authenticate a developer | `thalamus_cli` |
| Web app / SPA with its own callback URL | Register your own client via `npx zea-auth-init` |
| Backend service (M2M) | Register a confidential client with `client_credentials` grant |
| Mobile app | Register your own public client |

### Registered OAuth2 Clients Reference

| Client ID | Type | Purpose | Auto-Approve |
|---|---|---|---|
| `thalamus_cli` | public | Bootstrap — authenticates developers for CLI tools | ✅ Yes |
| `platform_web` | public | ZEA Platform web application | ✅ Yes |
| `cerebelum_service` | confidential | M2M — Cerebelum Workflow Engine ↔ Thalamus | N/A (M2M) |
| `internal_login` | confidential | API login endpoint (`/api/public/login`) | N/A (API) |
| `app_*` | public | User-registered apps via `zea-auth-init` | ✅ Yes |

---

## Error Responses

All OAuth2 errors follow RFC 6749 §5.2 format:

```json
{
  "error": "invalid_grant",
  "error_description": "PKCE verification failed"
}
```

| Error Code | HTTP Status | Meaning |
|---|---|---|
| `invalid_request` | 400 | Missing or invalid parameter |
| `invalid_client` | 401 | Client authentication failed |
| `invalid_grant` | 400 | Code/token invalid, expired, or revoked |
| `invalid_scope` | 400 | Requested scopes not allowed |
| `unsupported_grant_type` | 400 | Grant type not supported |
| `access_denied` | 302 | User denied authorization |
| `server_error` | 500 | Internal server error |

---

## Guides

| Guide | Description |
|---|---|
| [Authorization Code Flow](authorization-code.md) | Full PKCE flow: `/authorize` → `/token` |
| [Client Credentials (M2M)](client-credentials.md) | Machine-to-machine auth |
| [Token Introspection](token-introspection.md) | Validate tokens (RFC 7662) |
| [Token Revocation](token-revocation.md) | Revoke tokens (RFC 7009) |
| [UserInfo Endpoint](userinfo.md) | OpenID Connect user info |
| [Discovery & JWKS](discovery.md) | OIDC Discovery + public keys |
| [Agent Tokens](agent-tokens.md) | AI agent tokens with task-scoping |
