# Tasks v2: Documentación Thalamus — Persona-first + Cobertura Código → Docs

> **Plan**: [`docs-coverage-v2-2026-07-03-2020-b7d4e9f2`](docs-coverage-v2-2026-07-03-2020-b7d4e9f2.md)  
> **Hash**: `b7d4e9f2`  
> **Versión anterior**: `a3f8b2c1`  
> **Creado**: 2026-07-03 20:20 UTC  
> **Cobertura inicial**: ~6% (9/146)  
> **Objetivo**: ~88% (~140/160 con agents)

---

## 🔴 P1 — OAuth2 Core (8 archivos) ✅ COMPLETADO

Endpoints que definen a Thalamus como servicio OAuth2. Referencia canónica compartida cloud/on-prem.

- [x] **`docs/oauth2/overview.md`** — Grants, PKCE, scopes, token lifecycle, first-party auto-approval
- [x] **`docs/oauth2/authorization-code.md`** — GET/POST /oauth/authorize → POST /oauth/token + PKCE
- [x] **`docs/oauth2/client-credentials.md`** — M2M, Python + Node.js examples
- [x] **`docs/oauth2/token-introspection.md`** — RFC 7662, standard + agent fields
- [x] **`docs/oauth2/token-revocation.md`** — RFC 7009, HTTP Basic Auth
- [x] **`docs/oauth2/userinfo.md`** — OIDC userinfo + organizations
- [x] **`docs/oauth2/discovery.md`** — OIDC Discovery + JWKS
- [x] **`docs/oauth2/agent-tokens.md`** — Agent types, delegation chains, feature flag

---

## 🟠 P1.5 — Agents (3 archivos NUEVOS) ✅ COMPLETADO

Sección dedicada para agentes de código que usan Thalamus cloud vía CLI. Skills, scopes, flujo de autenticación.

- [x] **`docs/agents/overview.md`** — Cómo un agente interactúa con Thalamus
  - _Código_: `AgentTokenController` (OAuth2), `GenerateAgentToken` use case, `AgentToken` entity, `ValidateStepAuthorization` use case
  - _Contenido_: Flujo de autenticación de agentes, agent types, delegation, ciclo de vida del token, diferencias con user tokens
- [x] **`docs/agents/cli.md`** — CLI reference para agentes
  - _Código_: `AgentTokenController` (API), `InternalAgentConfigController`, `AuthorizationController.validate_step`
  - _Contenido_: Comandos: login, whoami, create-token, introspect, revoke, list-skills, validate-step
- [x] **`docs/agents/skills.md`** — Catálogo de skills/scopes
  - _Código_: `Scope` value object, `agent_type.ex` value object, `AgentToken` entity (scopes field), `GenerateAgentToken` use case (scope validation)
  - _Contenido_: Skills disponibles por agent_type, cómo declarar skills, validación de scopes contra client allowed_scopes, scopes sugeridos por tarea

---

## 🟡 P2 — API REST (11 archivos) ✅ COMPLETADO

CRUD y operaciones que usan developers y admins después de autenticarse.

- [x] **`docs/api/rest.md`** — Visión general: auth headers, paginación, rate limiting, formato respuestas
- [x] **`docs/api/authentication.md`** — Login, registro, verificación email, password reset
- [x] **`docs/api/users.md`** — CRUD /api/users, avatar, password change
- [x] **`docs/api/organizations.md`** — CRUD, members, SAML config
- [x] **`docs/api/clients.md`** — CRUD OAuth2 clients, rotate-secret, add-redirect-uri, validate
- [x] **`docs/api/roles.md`** — CRUD roles, user-role assignments, effective-scopes
- [x] **`docs/api/mfa.md`** — TOTP setup, verify, disable, backup codes
- [x] **`docs/api/secrets.md`** — CRUD secrets, internal resolve
- [x] **`docs/api/domains.md`** — Domain-agnostic RBAC
- [x] **`docs/api/personal-access-tokens.md`** — CRUD PATs
- [x] **`docs/api/audit-logs.md`** — Export CSV/JSON

---

## 🟢 P3 — Arquitectura + Configuración + Guías (5 archivos) ✅ COMPLETADO

- [x] **`docs/architecture/overview.md`** — Clean Architecture, 4 capas, entidades, VOs, use cases, puertos, plugs
- [x] **`docs/configuration.md`** — Unificar EMAIL_CONFIGURATION + ORGANIZATION_PLANS + env vars
- [x] **`docs/guides/saml-sso.md`** — /auth/saml/* + SAML config en organizations
- [x] **`docs/deployment.md`** — Renombrar y revisar DEPLOYMENT_GUIDE.md
- [x] **`docs/guides/dashboard-user-guide.md`** — ⚠️ Referencia a `/dashboard` que no existe en código (solo LiveDashboard en dev). Archivo mantenido como referencia futura.

---

## ⚪ P4 — Limpieza, entry points y cierre (6 archivos) ✅ COMPLETADO

- [x] **`docs/index.md`** — Router por persona: 5 caminos con links a docs existentes
- [x] **`docs/getting-started.md`** — Secciones por persona (dev, agente, devops, admin, arquitecto) con quickstart code
- [x] **Eliminar `docs/README.md`** — Reemplazado por `index.md`
- [x] **Archivar `docs/INTEGRATION_GUIDE.md`** — Movido a `docs/archive/`
- [x] **Verificar links rotos** — Corregidos en admin-api-keys, oauth2-client-management, tutorials/README
- [x] **Actualizar `CLAUDE.md`** — Recursos, OAuth2 endpoints, agent tokens, documentación de features

---

## 📊 Progreso

| Fase | Archivos | Completados | % |
|---|---|---|---|
| 🔴 P1 OAuth2 Core | 8 | 8 | 100% |
| 🟠 P1.5 Agents | 3 | 3 | 100% |
| 🟡 P2 API REST | 11 | 11 | 100% |
| 🟢 P3 Arquitectura + Config | 5 | 5 | 100% |
| ⚪ P4 Limpieza + Entry points | 6 | 6 | 100% |
| **TOTAL** | **33** | **33** | **100%** |

---

## Personas × Documentos (matriz de navegación)

| Documento | 🟦 Dev | 🤖 Agente | 🟢 DevOps | 🟣 Admin | 🟡 Arquitecto |
|---|---|---|---|---|---|
| `getting-started.md` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `oauth2/overview.md` | ✅ | ✅ | — | ✅ | ✅ |
| `oauth2/authorization-code.md` | ✅ | — | — | — | — |
| `oauth2/client-credentials.md` | ✅ | — | — | — | — |
| `oauth2/token-introspection.md` | ✅ | ✅ | — | ✅ | — |
| `oauth2/token-revocation.md` | ✅ | ✅ | — | ✅ | — |
| `oauth2/userinfo.md` | ✅ | ✅ | — | — | — |
| `oauth2/discovery.md` | ✅ | — | ✅ | — | — |
| `oauth2/agent-tokens.md` | — | ✅ | — | — | ✅ |
| `agents/overview.md` | — | ✅ | — | — | — |
| `agents/cli.md` | — | ✅ | — | — | — |
| `agents/skills.md` | — | ✅ | — | ✅ | — |
| `api/*` | ✅ | ✅ | — | ✅ | — |
| `guides/admin-api-keys.md` | ✅ | — | ✅ | ✅ | — |
| `guides/saml-sso.md` | — | — | ✅ | ✅ | — |
| `architecture/overview.md` | — | — | ✅ | — | ✅ |
| `deployment.md` | — | — | ✅ | — | — |
| `configuration.md` | — | — | ✅ | ✅ | — |
| `tutorials/*` | ✅ | — | — | — | — |
