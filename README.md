# 🔐 ZEA Thalamus — Auth & Identity

**Enterprise OAuth2 + Multi-tenancy + User/Org Management**

[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

---

## 🚀 From Zero (3 segundos)

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
