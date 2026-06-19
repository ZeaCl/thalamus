# 🔐 ZEA Thalamus — Auth & Identity

**Enterprise OAuth2 + Multi-tenancy + User/Org Management**

[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

---

## 🎯 Features

### Core OAuth2 (RFC Compliant)
- ✅ **Authorization Code Grant** (RFC 6749)
- ✅ **Client Credentials Grant** (RFC 6749)
- ✅ **Refresh Token Grant** (RFC 6749)
- ✅ **PKCE Support** (RFC 7636)
- ✅ **Token Introspection** (RFC 7662)
- ✅ **Token Revocation** (RFC 7009)

### Security & Authentication
- 🔒 **Multi-Factor Authentication** (TOTP)
- 🔒 **Backup Codes** for account recovery
- 🔒 **Email Verification** with secure tokens
- 🔒 **Password Reset** with anti-enumeration
- 🔒 **Admin API Keys** for service-to-service authentication
- 🔒 **Rate Limiting** (per IP, user, client)
- 🔒 **CORS Configuration** with origin whitelisting
- 🔒 **Security Headers** (CSP, HSTS, X-Frame-Options)
- 🔒 **Audit Logging** for all security events

### Enterprise Features
- 🏢 **Multi-Tenancy** with organization management
- 🏢 **Role-Based Access Control** (RBAC)
- 🏢 **User Management** API
- 🏢 **Client Application** management
- 🏢 **Flexible Plans** (Free, Starter, Professional, Enterprise)

### Developer Experience
- 📦 **TypeScript SDK** (`@zea/thalamus-js`) - Zero dependencies, fully typed
- 📚 **OpenAPI 3.0 Documentation** (Swagger)
- 🎯 **Complete Examples** (Next.js 14, Direct API integration)
- 🐳 **Docker & Docker Compose** ready
- 🔧 **Makefile** with common commands
- 🧪 **Comprehensive Test Suite** (189 tests passing)
- 📖 **Complete Documentation**

### Admin Dashboard (NEW ✨)
- 🎨 **Modern Web UI** built with Phoenix LiveView
- 📊 **Real-time Statistics** (users, clients, organizations, tokens)
- 👥 **User Management** (CRUD operations, password reset, status management)
- 🔑 **OAuth2 Clients** (create, edit, rotate secrets, view tokens)
- 🏢 **Organizations** (manage plans, users, settings)
- 🎫 **Token Management** (view, revoke, filter by status)
- 📝 **Audit Logs** (immutable security trail, advanced filtering)
- 🧭 **Breadcrumb Navigation** for better UX
- ⚡ **Loading States** with skeleton screens
- 🌓 **Dark/Light/System Themes**

---

## 📊 Project Status

**Version:** 0.9.0
**Status:** Production-Ready
**Completion:** 84% (36/43 tasks)

### Implementation Status
- ✅ Domain Layer: 100%
- ✅ Application Layer: 100%
- ✅ Infrastructure Layer: 100%
- ✅ Web Dashboard: 100% (NEW ✨)
- ✅ Presentation Layer: 100%
- ✅ Security: 100%
- ✅ Admin API Keys: 100%
- ✅ Audit & Monitoring: 100% (NEW ✨)
- ✅ UX & Polish: 100% (NEW ✨)
- ⚠️  Testing: 80% (189 tests passing)
- ⚠️  Documentation: 90%

See [STATUS.md](STATUS.md) for detailed status.

---

## 📦 SDK & Examples

### TypeScript SDK

```bash
npm install @zea/thalamus-js
```

```typescript
import { ThalamusClient } from '@zea/thalamus-js'

const thalamus = new ThalamusClient({
  clientId: 'your_client_id',
  clientSecret: 'your_client_secret',
  redirectUri: 'http://localhost:3000/auth/callback',
  baseUrl: 'http://localhost:4000',
})

// OAuth2 Authorization Code flow
const authUrl = thalamus.auth.getAuthorizationUrl({ state: 'random-state' })
const tokens = await thalamus.auth.exchangeCode('authorization_code')
const user = await thalamus.tokens.getUserInfo(tokens.access_token)
```

**Features:**
- ✅ Zero dependencies
- ✅ Full TypeScript support
- ✅ OAuth2 2.0 compliant
- ✅ All grant types supported
- ✅ Token introspection & revocation

[View SDK Documentation →](./packages/thalamus-js/README.md)

### Examples

- **[Next.js 14 App Router](./examples/nextjs-app-router)** - Complete OAuth2 integration with React Server Components
- **[Direct API Example](./examples/direct-api)** - Integration without SDK using vanilla `fetch()`

[View All Examples →](./examples/README.md)

---

## 🚀 Quick Start

### Prerequisites

- **Elixir** 1.17+ and **Erlang** 26+
- **PostgreSQL** 16+
- **Redis** 7+ (optional, for rate limiting)
- **Docker** & **Docker Compose** (optional)

### Option 1: Docker (Recommended)

```bash
npm install @zea/thalamus-sdk
npx thalamus-init
```

→ Abre navegador → Registrate → **User + Org + OAuth client creados automáticamente** ✅

```tsx
import { LoginButton, useThalamus } from '@zea/thalamus-sdk'

function App() {
  const { token, user, isAuthenticated } = useThalamus({
    clientId: 'my_app',
    redirectUri: `${location.origin}/callback`,
    baseUrl: 'https://auth.zea.cl',
  })

  if (!isAuthenticated) return <LoginButton config={...} />
  return <Dashboard user={user} />
}
```

---

## 📦 SDK Components

| Component | Descripción |
|---|---|
| `LoginButton` | OAuth2 PKCE login en 1 click |
| `RegisterButton` | Registro con org + app origin |
| `UserMenu` | Avatar + logout |
| `UserCreateForm` | Formulario crear usuarios/agentes |
| `UserTable` | Tabla de usuarios |
| `OrgManager` | Lista organizaciones |
| `APIKeyManager` | Generar/revocar API keys |
| `OrgSwitcher` | Dropdown cambiar de org |

## 🪝 Hooks

| Hook | Descripción |
|---|---|
| `useThalamus()` | `login`, `logout`, `token`, `user`, `isAuthenticated` |
| `useAdmin()` | `users`, `agents`, `createUser`, `listDomainRoles` |

---

## 🔧 API

| Endpoint | Descripción |
|---|---|
| `POST /oauth/token` | Token exchange (PKCE) |
| `POST /oauth/introspect` | Validar token |
| `GET /oauth/userinfo` | Info del usuario |
| `GET/POST /api/users` | CRUD usuarios |
| `GET /api/organizations` | Listar orgs |
| `POST /api/domains/roles/grant` | Asignar roles |

---

## 🛡️ Seguridad

- ✅ OAuth2 PKCE (SPA, sin secret)
- ✅ Client credentials (M2M)
- ✅ Refresh token rotation
- ✅ Rate limiting en `/register` (5/min por IP)
- ✅ CORS por origin automático
- ✅ CSRF protection (state param)
- ✅ Public/confidential clients

---

## 🏗️ Arquitectura

```
thalamus/
├── lib/          # Backend Phoenix (Clean Architecture + SOLID)
├── sdk/          # @zea/thalamus-sdk (React + CLI)
├── skill/        # Skills para agentes
└── config/       # Configuración
```

---

## 📄 Licencia

MIT — [ZEA Platform](https://github.com/zeacl)
