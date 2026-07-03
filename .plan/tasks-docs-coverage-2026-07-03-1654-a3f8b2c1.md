# Tasks: Documentación Thalamus — Cobertura Código → Docs

> **Plan**: [`docs-coverage-2026-07-03-1654-a3f8b2c1`](docs-coverage-2026-07-03-1654-a3f8b2c1.md)  
> **Hash**: `a3f8b2c1`  
> **Creado**: 2026-07-03 16:54 UTC  
> **Cobertura inicial**: ~6% (9/146)  
> **Objetivo**: ~85% (125/146)

---

## 🔴 P1 — OAuth2 Core (8 archivos) ✅ COMPLETADO

Estos son los endpoints que definen a Thalamus como servicio OAuth2. Sin esto, ningún integrador puede trabajar.

- [x] **`docs/oauth2/overview.md`** — Grants soportados, PKCE, scopes, flujos, modelo de token
  - _Código_: `TokenController`, `AuthorizationController`, value objects (`grant_type.ex`, `scope.ex`, `pkce_challenge.ex`)
- [x] **`docs/oauth2/authorization-code.md`** — `GET/POST /oauth/authorize` + `POST /oauth/token` (grant_type=authorization_code)
  - _Código_: `AuthorizationController` (new, create), `TokenController` (create)
- [x] **`docs/oauth2/client-credentials.md`** — `POST /oauth/token` (grant_type=client_credentials), M2M
  - _Código_: `TokenController` (create, extract_token_params)
- [x] **`docs/oauth2/token-introspection.md`** — `POST /oauth/introspect` (RFC 7662)
  - _Código_: `IntrospectionController` (create, perform_introspection, build_introspection_response)
- [x] **`docs/oauth2/token-revocation.md`** — `POST /oauth/revoke` (RFC 7009)
  - _Código_: `RevocationController` (create, perform_revocation, authenticate_client)
- [x] **`docs/oauth2/userinfo.md`** — `GET /oauth/userinfo` (OpenID Connect)
  - _Código_: `UserinfoController` (show, extract_bearer_token)
- [x] **`docs/oauth2/discovery.md`** — `GET /.well-known/openid-configuration` + `GET /.well-known/jwks.json`
  - _Código_: `DiscoveryController` (show), `JwksController` (show)
- [x] **`docs/oauth2/agent-tokens.md`** — `POST /oauth/agent-token` (agentes IA, delegation chain)
  - _Código_: `AgentTokenController` (OAuth2), `GenerateAgentToken` use case, `AgentToken` entity

---

## 🟡 P2 — API REST (11 archivos)

Endpoints que usan developers después de autenticarse. Son el 80% de las operaciones diarias.

- [ ] **`docs/api/rest.md`** — Visión general: auth headers, paginación, rate limiting, formato respuestas
  - _Código_: `router.ex` (pipelines), plugs (`AuthenticateToken`, `APIAuth`, `RateLimiter`, `CORS`)
- [ ] **`docs/api/authentication.md`** — `POST /api/public/login`, `POST /api/public/register`, `POST /api/public/verify-email`, `POST /api/public/resend-verification`, `POST /api/public/password/reset`, `POST /api/public/password/confirm-reset`
  - _Código_: `LoginController`, `RegistrationController`, `PasswordController`
- [ ] **`docs/api/users.md`** — `CRUD /api/users`, `PUT /api/password/change`, `POST/DELETE /api/avatar`
  - _Código_: `UserController`, `PasswordController`, `AvatarController`
- [ ] **`docs/api/organizations.md`** — `CRUD /api/organizations`, `POST/DELETE /api/organizations/:id/members`, `GET/PUT/DELETE /api/organizations/:id/saml-config`
  - _Código_: `OrganizationController`
- [ ] **`docs/api/clients.md`** — `CRUD /api/clients`, `POST rotate-secret`, `POST add-redirect-uri`, `GET validate`
  - _Código_: `OAuth2ClientController` — **mergear** contenido de `guides/oauth2-client-management.md` y `guides/oauth2-client-secret-rotation.md`
- [ ] **`docs/api/roles.md`** — `CRUD /api/roles`, `POST/DELETE /api/users/:user_id/roles`, `GET /api/users/:user_id/roles`, `GET /api/users/:user_id/effective-scopes`
  - _Código_: `RoleController`, `UserRoleController`
- [ ] **`docs/api/mfa.md`** — `POST /api/mfa/totp/setup`, `POST /api/mfa/totp/verify`, `POST /api/mfa/verify`, `DELETE /api/mfa/disable`, `POST /api/mfa/backup-codes/regenerate`
  - _Código_: `MFAController`
- [ ] **`docs/api/secrets.md`** — `CRUD /api/secrets`, `GET /api/internal/secrets/resolve`
  - _Código_: `SecretController`
- [ ] **`docs/api/domains.md`** — `GET /api/domains`, `POST /api/domains/register`, `POST/DELETE grant/revoke`, `GET list_roles`
  - _Código_: `DomainController`
- [ ] **`docs/api/personal-access-tokens.md`** — `CRUD /api/personal-access-tokens`
  - _Código_: `PersonalAccessTokenController`
- [ ] **`docs/api/audit-logs.md`** — `GET /api/audit-logs/export` (CSV/JSON, filtros por fecha/organización)
  - _Código_: `AuditLogController`

---

## 🟢 P3 — Arquitectura + Configuración + Guías (5 archivos)

- [ ] **`docs/architecture/overview.md`** — Clean Architecture, 4 capas, 9 entidades, 21 value objects, 19 use cases, 14 puertos, 8 plugs, supervision tree
  - _Código_: Todo `lib/thalamus/` + `lib/thalamus_web/`
- [ ] **`docs/configuration.md`** — Unificar `EMAIL_CONFIGURATION.md` + `ORGANIZATION_PLANS_CONFIGURATION.md` + env vars generales
  - _Código_: `config/`, `FeatureFlags`
- [ ] **`docs/guides/saml-sso.md`** — `GET /auth/saml/init`, `POST /auth/saml/acs`, `GET /auth/saml/metadata/:id` + SAML config en organizations
  - _Código_: `SamlController`, `OrganizationController` (show_saml_config, update_saml_config, delete_saml_config), `SamlIdentityProvider` entity
- [ ] **`docs/deployment.md`** — Renombrar y revisar `DEPLOYMENT_GUIDE.md` (17KB)
- [ ] **`docs/guides/dashboard-user-guide.md`** — Revisar que siga siendo preciso contra código actual

---

## ⚪ P4 — Limpieza y cierre

- [ ] **`docs/index.md`** — Nuevo hub central, siguiendo patrón cerebelum-core (SOLO linkea archivos existentes)
- [ ] **Eliminar `docs/README.md`** — Reemplazado por `index.md`
- [ ] **Archivar `docs/INTEGRATION_GUIDE.md`** — 89KB, contenido migrado a `api/` y `oauth2/`
- [ ] **Revisar `docs/tutorials/README.md`** — Actualizar links post-reorganización
- [ ] **Verificar que NO quedan links rotos** — `grep -r "\[.*\](.*\.md)" docs/` y validar
- [ ] **Actualizar `CLAUDE.md`** — Referencias a nueva estructura de docs

---

## 📊 Progreso

| Fase | Archivos | Completados | % |
|---|---|---|---|
| 🔴 P1 OAuth2 Core | 8 | 8 | 100% |
| 🟡 P2 API REST | 11 | 0 | 0% |
| 🟢 P3 Arquitectura + Config | 5 | 0 | 0% |
| ⚪ P4 Limpieza | 6 | 0 | 0% |
| **TOTAL** | **30** | **8** | **27%** |

---

## 📝 Notas de ejecución

- Cada task se valida leyendo el código fuente del controller/ex correspondiente **antes** de escribir
- Formato cerebelum-core: tabla de endpoints → parámetros → ejemplos curl → error codes
- Commits atómicos: un archivo = un commit con mensaje `docs(nombre): descripción`
- El `index.md` se crea al final, cuando todos los archivos existen
