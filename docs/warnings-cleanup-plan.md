# Paso 7 — Plan de limpieza de warnings

**Objetivo:** Eliminar todos los warnings de compilación y test
**Estado actual:** ~40 warnings en total (no rompen la build local por typo en `mix.exs`)

---

## 🔍 Categorización

### 7.1 — Variables sin usar `[ ]`
**Archivos:** 12 archivos · **Fix:** `_` prefix o eliminar

| # | Archivo | Línea | Variable | Fix |
|---|---------|-------|----------|-----|
| 1 | `token_controller_test.exs` | 72,141,170,271,397,450 | `read_scope` (6x) | `_read_scope` |
| 2 | `user_controller_test.exs` | 43 | `scopes` | `_scopes` |
| 3 | `mfa_controller_test.exs` | 44 | `scopes` | `_scopes` |
| 4 | `organization_controller_test.exs` | 43 | `scopes` | `_scopes` |
| 5 | `user_controller_test.exs` | 58 | `client_uuid` | `_client_uuid` |
| 6 | `password_controller_test.exs` | 49 | `client_uuid` | `_client_uuid` |
| 7 | `mfa_controller_test.exs` | 58 | `client_uuid` | `_client_uuid` |
| 8 | `organization_controller_test.exs` | 58 | `client_uuid` | `_client_uuid` |
| 9 | `agent_token_controller_test.exs` | 198 | `client` (pin) | `_client` |
| 10 | `oauth2_flow_test.exs` | 34-40 | `client_id`, `auth_code_grant`, `refresh_grant`, `client_creds_grant`, `read_scope`, `write_scope`, `redirect_uri` | `_` prefix |
| 11 | `assign_role_test.exs` | 88 | `role` | `_role` |
| 12 | `oauth2_client_test.exs` | 163,212 | `uri2`, `email` | `_` prefix |
| 13 | `token_repository_test.exs` | 207 | `user_id` | `_user_id` |
| 14 | `personal_access_token_controller_test.exs` | 136 | `user_id` | `_user_id` |
| 15 | `admin_api_key_controller_test.exs` | 228 | `old_prefix` | `_old_prefix` |
| 16 | `agent_token_controller.ex` (prod) | 289 | `error` | `_error` |

---

### 7.2 — Variables shadowing del contexto `[ ]`
**Archivos:** 4 archivos · **Fix:** `_org` o pin `^org`

| # | Archivo | Línea | Issue |
|---|---------|-------|-------|
| 17 | `user_controller_test.exs` | 18 | `{:ok, org} = ...` shadows `org` del setup |
| 18 | `password_controller_test.exs` | 18 | Ídem |
| 19 | `mfa_controller_test.exs` | 20 | Ídem |
| 20 | `organization_controller_test.exs` | 18 | Ídem |

---

### 7.3 — Aliases sin usar `[ ]`
**Archivos:** 12 archivos · **Fix:** Eliminar alias

| # | Archivo | Alias a borrar |
|---|---------|---------------|
| 21 | `oauth2_client_test.exs:5` | `ClientId` |
| 22 | `introspection_controller_test.exs:5` | `ClientId`, `GrantType`, `RedirectUri` |
| 23 | `revocation_controller_test.exs:5` | `ClientId`, `GrantType`, `RedirectUri` |
| 24 | `authorization_controller_test.exs:5` | `ClientId`, `GrantType`, `RedirectUri`, `Scope` |
| 25 | `token_controller_test.exs:4` | `Repo` |
| 26 | `token_controller_test.exs:6` | `ClientId`, `GrantType` |
| 27 | `user_controller_test.exs:6` | `TestHelpers` |
| 28 | `user_controller_test.exs:8` | `PostgreSQLOAuth2ClientRepository` |
| 29 | `password_controller_test.exs:6` | `TestHelpers` |
| 30 | `password_controller_test.exs:8` | `PostgreSQLOAuth2ClientRepository` |
| 31 | `mfa_controller_test.exs:6` | `TestHelpers` |
| 32 | `mfa_controller_test.exs:8` | `PostgreSQLOAuth2ClientRepository` |
| 33 | `mfa_controller_test.exs:15` | `RedisCacheAdapter` |
| 34 | `organization_controller_test.exs:6` | `TestHelpers` |
| 35 | `organization_controller_test.exs:8` | `PostgreSQLOAuth2ClientRepository` |
| 36 | `domain_controller_test.exs:6` | `OrganizationSchema`, `UserSchema` |
| 37 | `agent_token_controller_test.exs:8` | `PostgreSQLTokenRepository` |
| 38 | `agent_token_controller_test.exs:4` | `UserId` |
| 39 | `authorization_code_test.exs:4` | `PKCEChallenge` |

---

### 7.4 — Default args nunca usados `[ ]`
**Archivos:** 4 archivos · **Fix:** Quitar default

| # | Archivo | Línea | Función |
|---|---------|-------|---------|
| 40 | `generate_agent_token_test.exs` | 334 | `build_client(org_id \\ nil)` |
| 41 | `generate_agent_token_test.exs` | 347 | `build_user(org_id \\ nil)` |
| 42 | `generate_agent_token_test.exs` | 357 | `build_saved_agent_token(overrides \\ %{})` |
| 43 | `generate_agent_token_test.exs` | 396 | `setup_successful_mocks(org_id \\ nil)` |
| 44 | `token_repository_test.exs` | 730 | `insert_expired_token(overrides \\ [])` |
| 45 | `validate_step_authorization_test.exs` | 218 | `build_agent_token(overrides \\ [])` |

---

### 7.5 — Comparaciones entre tipos distintos `[ ]`
**Archivo:** 1 archivo · **Fix:** `assert spec` en vez de `assert spec != nil`

| # | Archivo | Línea | Issue |
|---|---------|-------|-------|
| 46 | `redis_cache_adapter_test.exs` | 352,363,378,392 | `assert spec != nil` — spec siempre es map, nunca nil |

---

### 7.6 — Clause que nunca matchea `[ ]`
**Archivo:** 1 archivo

| # | Archivo | Línea | Issue |
|---|---------|-------|-------|
| 47 | `agent_token_test.exs` | 477 | Pattern match sobre `revoked_token` con `%AgentToken{status: :active}` — imposible |

---

### 7.7 — Funciones sin usar `[ ]`
**Archivos:** 2 archivos

| # | Archivo | Línea | Función |
|---|---------|-------|---------|
| 48 | `authorization_controller_test.exs` | 45 | `put_user_session/2` |
| 49 | `oauth2_flow_test.exs` | 63 | `put_user_session/2` |

---

### 7.8 — Deprecation `[ ]`
**Archivo:** 1 archivo

| # | Archivo | Línea | Issue |
|---|---------|-------|-------|
| 50 | `registration_controller_test.exs` | 28 | `get_flash/2` deprecated → `Phoenix.Flash.get/2` |

---

### 7.9 — Cláusulas agrupadas `[ ]`
**Archivo:** 1 archivo (producción)

| # | Archivo | Issue |
|---|---------|-------|
| 51 | `organization.ex:250` | `add_member/3` definido en dos lugares separados |

---

### 7.10 — Typo en `mix.exs` `[ ]`
**Archivo:** 1 archivo

| # | Archivo | Issue |
|---|---------|-------|
| 52 | `mix.exs` | `"compile --warning-as-errors"` → `"compile --warnings-as-errors"` |

---

## 📊 Resumen

| Categoría | Items | Dificultad |
|-----------|:---:|:---:|
| Variables sin usar | 16 | Trivial |
| Variables shadowing | 4 | Trivial |
| Aliases sin usar | 19 | Trivial |
| Default args sin usar | 6 | Trivial |
| Comparaciones tipos distintos | 4 | Fácil |
| Clause nunca matchea | 1 | Fácil |
| Funciones sin usar | 2 | Fácil |
| Deprecation | 1 | Fácil |
| Cláusulas agrupadas | 1 | Medio (producción) |
| Typo mix.exs | 1 | Trivial |
| **Total** | **55** | |

## 🔢 Orden

1. **7.2** — Variables shadowing (4 tests)
2. **7.1** — Variables sin usar (16 en 12 archivos)
3. **7.3** — Aliases sin usar (19 en 12 archivos)
4. **7.4** — Default args (6 en 4 archivos)
5. **7.5** — Type comparisons (4 en 1 archivo)
6. **7.6** — Clause never matches (1)
7. **7.7** — Funciones sin usar (2)
8. **7.8** — Deprecation (1)
9. **7.9** — Cláusulas agrupadas (1, producción)
10. **7.10** — Typo mix.exs (1)
