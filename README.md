# 🔐 Thalamus — OAuth2 & Identity Provider

**Enterprise-grade authentication and authorization service. OAuth2, OpenID Connect, MFA, RBAC, multi-tenancy. Built with Elixir + Phoenix.**

[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)

---

## 🚀 Quick Start

```bash
# Install dependencies, create DB, run migrations
make setup

# Start the server
make dev
```

Open `http://localhost:4000`. That's it.

**Prerequisites:** Elixir 1.19+, Erlang 28+, PostgreSQL 16+. Redis 7+ optional.

### Docker

```bash
docker-compose up -d
```

---

## ✨ Features

| Category | Capabilities |
|---|---|
| **OAuth2 / OIDC** | Authorization Code + PKCE, Client Credentials, Refresh Token rotation, Token Introspection (RFC 7662), Token Revocation (RFC 7009), OpenID Connect Discovery, JWKS, UserInfo |
| **Security** | MFA (TOTP + backup codes), Bcrypt password hashing, Rate limiting (per IP/user/client), CORS, CSP/HSTS security headers, CSRF protection, Constant-time token comparison |
| **Multi-tenancy** | Organizations with flexible plans (Free/Starter/Professional/Enterprise), Isolated user bases per org |
| **RBAC** | Roles, permissions, domain-scoped roles, delegation chains, effective scope resolution |
| **Agent Tokens** | Delegated tokens for multi-agent systems, task-level scoping, intent attestation, max operations tracking |
| **Audit** | Immutable security event log, export API, advanced filtering |
| **Admin** | LiveView dashboard, User/Client/Org/Token CRUD, Admin API Keys for M2M auth, Personal Access Tokens |
| **SAML SSO** | Identity provider configuration, assertion validation, attribute mapping |

---

## 🔌 API Overview

### OAuth2 Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` `/POST` | `/oauth/authorize` | Authorization endpoint (user consent) |
| `POST` | `/oauth/token` | Token exchange (all grant types) |
| `POST` | `/oauth/introspect` | Token validation (RFC 7662) |
| `POST` | `/oauth/revoke` | Token revocation (RFC 7009) |
| `POST` | `/oauth/agent-token` | Agent token generation |
| `GET` | `/oauth/userinfo` | OpenID Connect user info |
| `GET` | `/.well-known/openid-configuration` | OIDC Discovery |
| `GET` | `/.well-known/jwks.json` | JWKS public keys |

### Management API

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/public/register` | User registration |
| `POST` | `/api/public/login` | Password login |
| `GET/POST/PUT/DELETE` | `/api/users` | User CRUD |
| `GET/POST/PUT/DELETE` | `/api/organizations` | Organization management |
| `GET/POST/PUT/DELETE` | `/api/clients` | OAuth2 client management |
| `GET/POST/PUT/DELETE` | `/api/roles` | Role management |
| `GET/POST/DELETE` | `/api/secrets` | Agent secrets |
| `POST/DELETE` | `/api/domains/roles/grant` | Domain-scoped role assignment |
| `GET` | `/api/audit-logs/export` | Audit log export |
| `GET` | `/api/public/health` | Health check |

Full spec: [`docs/OPENAPI_SPEC.yaml`](docs/OPENAPI_SPEC.yaml)

---

## 📦 SDK

```bash
npm install @zea/thalamus-js
```

```typescript
import { ThalamusClient } from '@zea/thalamus-js'

const thalamus = new ThalamusClient({
  clientId: 'your_client_id',
  redirectUri: 'http://localhost:3000/callback',
  baseUrl: 'http://localhost:4000',
})

// OAuth2 PKCE flow
const authUrl = thalamus.auth.getAuthorizationUrl({ state: crypto.randomUUID() })
// ... after redirect:
const tokens = await thalamus.auth.exchangeCode(code, codeVerifier)
const user = await thalamus.tokens.getUserInfo(tokens.access_token)
```

React components (`@zea/thalamus-sdk`): `LoginButton`, `RegisterButton`, `UserMenu`, `UserTable`, `OrgManager`, `APIKeyManager`, `OrgSwitcher`.

Hooks: `useThalamus()` (login, logout, token, user), `useAdmin()` (users, agents, roles).

---

## 📖 Documentation

| Doc | Audience |
|---|---|
| [Integration Guide](docs/INTEGRATION_GUIDE.md) | Teams integrating their app with Thalamus |
| [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) | DevOps deploying to production |
| [OpenAPI Spec](docs/OPENAPI_SPEC.yaml) | API reference (Swagger) |
| [Admin API Keys](docs/guides/admin-api-keys.md) | Service-to-service auth |
| [OAuth2 Client Management](docs/guides/oauth2-client-management.md) | Managing registered apps |
| [Secret Rotation](docs/guides/oauth2-client-secret-rotation.md) | Rotating client secrets |
| [Dashboard Guide](docs/guides/dashboard-user-guide.md) | Admin UI |
| [Tutorials](docs/tutorials/) | Step-by-step integration examples |
| [SDK Changelog](CHANGELOG_SDK.md) | SDK release history |

---

## 🏗️ Architecture

```
thalamus/
├── lib/
│   ├── thalamus/domain/         # Entities, Value Objects, Domain Services
│   ├── thalamus/application/    # Use Cases, Ports (interfaces), DTOs
│   ├── thalamus/infrastructure/ # PostgreSQL repos, Redis, SAML, Email adapters
│   └── thalamus_web/            # Controllers, Plugs, LiveView, Router
├── sdk/                         # @zea/thalamus-sdk (React + CLI)
├── priv/repo/migrations/        # Database migrations
├── config/                      # Environment configuration
└── test/                        # 1,820 tests, 0 failures
```

**Clean Architecture + SOLID** — Domain layer has zero external dependencies. Infrastructure implements ports defined by the application layer.

---

## 🧪 Development

```bash
make setup          # deps + db + migrate
make dev            # start server
mix test            # 1,820 tests
make check          # format + lint + test
make precommit      # compile --warnings-as-errors + format + test
```

---

## 📄 License

Apache 2.0 — [ZEA Platform](https://github.com/zeacl)
