# Implementation Plan — OAuth2 Client Validation Endpoint

## Overview

This implementation plan covers the addition of a diagnostic validation endpoint to Thalamus's OAuth2 client management API. The feature is read-only, requires no database changes, and extends the existing `OAuth2ClientController`. Total effort: ~1 sprint (~3 days).

---

## Sprint 1: Validation Endpoint (Días 1-3)

| ID | Tarea | Dep | Días | Criterio de aceptación |
|----|-------|-----|------|------------------------|
| T-01 | Crear `OAuth2ClientValidator` — checks de coherencia | — | 1 | El módulo existe en `lib/thalamus/application/`, `run/1` devuelve lista de check maps con `client_active`, `client_type_coherence`, `scopes`, `redirect_uris` |
| T-02 | Crear `OAuth2ClientValidator` — checks de CORS y CSP | T-01 | 0.5 | `check_cors_origins/1` lee `Application.get_env` de CORS y compara con redirect URIs. `check_csp_form_action/1` extrae `form-action` del CSP y compara dominios |
| T-03 | Crear `OAuth2ClientValidator` — checks de endpoint health | T-01 | 0.5 | `check_endpoint_health/0` usa `Req` para llamar JWKS, authorize, token. Cada endpoint reporta PASS/FAIL independientemente |
| T-04 | Agregar `validate/2` en `OAuth2ClientController` | T-03 | 0.5 | La acción existe, parsea `client_id` vía `ClientId.from_string`, busca cliente en repo, llama al validator, devuelve JSON con `status`, `summary`, `checks` |
| T-05 | Implementar ownership check `verify_user_in_client_org/2` | T-04 | 0.5 | Verifica que `conn.assigns.organization_id` matchea `client.organization_id` para PAT; verifica memberships para JWT; API Key pasa directo. Retorna 403 si no pertenece |
| T-06 | Agregar ruta en `router.ex` | T-05 | 0.25 | `get "/clients/:client_id/validate", OAuth2ClientController, :validate` en el scope `:api_auth` existente |
| T-07 | Unit tests para `OAuth2ClientValidator` | T-03 | 1 | Cada check function tiene al menos un test de PASS, FAIL, y edge case. Stub de `Application.get_env` y `Req` con Mox. `mix test test/thalamus/application/oauth2_client_validator_test.exs` pasa |
| T-08 | Controller tests para `validate/2` | T-06 | 0.5 | Tests: 200 con PAT válido, 200 con API Key, 403 desde org incorrecta, 401 sin auth, 400 con UUID inválido, 404 cliente no existe. `mix test test/thalamus_web/controllers/api/oauth2_client_controller_test.exs` pasa |
| T-09 | `mix precommit` — formato, credo, tests | T-08 | 0.25 | `mix format --check-formatted` pasa, `mix credo --strict` sin warnings nuevos, `mix test` todo verde |

### Resumen

| Sprint | Días | Tareas | Entregable |
|--------|------|--------|------------|
| 1. Validation Endpoint | 3 | T-01→T-09 | `GET /api/clients/:id/validate` funcional, testeado, listo para deploy |
| **Total** | **3** | **9** | **Endpoint de validación OAuth2** |

---

## Detalle de Tareas

### T-01: OAuth2ClientValidator — checks de coherencia

**Archivo:** `lib/thalamus/application/oauth2_client_validator.ex` (nuevo)

**Qué incluye:**
- `run/1` que recibe un `%OAuth2Client{}` y devuelve `[%{check: ..., status: ..., detail: ...}]`
- `check_client_active/1` — verifica `is_active`
- `check_client_type_coherence/1` — para `:public`: verifica `auth_method=none`, `pkce_required=true`, tiene `authorization_code`, tiene redirect URIs. Para `:confidential`: verifica `auth_method=client_secret_post`, tiene `client_credentials`
- `check_scopes/1` — verifica que `openid` esté en `allowed_scopes`
- `check_redirect_uris/1` — verifica formato `http://` o `https://` para cada URI

**Criterio de aceptación:**
```elixir
iex> client = %OAuth2Client{client_type: :public, is_active: true, allowed_scopes: [], ...}
iex> OAuth2ClientValidator.run(client)
[%{check: "has_openid_scope", status: "fail", detail: "openid scope is required..."}, ...]
```

---

### T-02: OAuth2ClientValidator — checks de CORS y CSP

**Archivo:** mismo `oauth2_client_validator.ex`

**Qué incluye:**
- `check_cors_origins/1` — lee `Application.get_env(:thalamus, ThalamusWeb.Plugs.CORS)`, extrae `:origins`, compara contra orígenes únicos de `redirect_uris`
- `check_csp_form_action/1` — lee `Application.get_env(:thalamus, ThalamusWeb.Plugs.SecurityHeaders)`, extrae `:csp_policy`, parsea `form-action`, verifica si cada dominio está cubierto (exacto o wildcard `*.dominio`)
- `extract_unique_origins/1`, `extract_form_action/1`, `csp_covers_host?/2` — helpers privados

**Criterio de aceptación:**
- Si `CORS_ORIGINS` no incluye `http://app.zea.localhost` y el cliente tiene ese redirect URI → FAIL con instrucción
- Si `form-action` tiene `http://*.zea.localhost:*` → cubre `app.zea.localhost` (PASS)
- Si `form-action` no cubre `zea.cl` → WARN

---

### T-03: OAuth2ClientValidator — checks de endpoint health

**Archivo:** mismo `oauth2_client_validator.ex`

**Qué incluye:**
- `check_endpoint_health/0` — llama a `check_jwks/1`, `check_authorize_endpoint/1`, `check_token_endpoint/1`
- Cada función usa `Req.get/1` o `Req.post/2` al `base_url` configurado
- `base_url` se lee de `Application.get_env(:thalamus, :base_url)`

**Criterio de aceptación:**
- JWKS retorna 200 → PASS
- JWKS retorna 500 → FAIL con detail "JWKS endpoint returned HTTP 500"
- JWKS unreachable → FAIL con detail "JWKS endpoint unreachable: %Req.TransportError{}"

---

### T-04: Agregar `validate/2` en OAuth2ClientController

**Archivo:** `lib/thalamus_web/controllers/api/oauth2_client_controller.ex` (editar)

**Qué incluye:**
- Nueva acción pública `validate/2` con `@doc`
- `with` block: `ClientId.from_string` → `find_by_id` → `verify_user_in_client_org` → `Validator.run` → JSON response
- Manejo de errores: `:invalid_id` → 400, `:not_found` → 404, `:forbidden` → 403
- Llama a `overall_status/1` y `count_statuses/1` del validator

**Criterio de aceptación:**
```bash
curl -H "Authorization: Bearer th_pat_xxx" \
  http://auth.zea.localhost/api/clients/{id}/validate
# → 200 con JSON {client_id, status, summary, checks}
```

---

### T-05: Ownership check `verify_user_in_client_org/2`

**Archivo:** mismo `oauth2_client_controller.ex`

**Qué incluye:**
- Función privada que recibe `conn` y `client`
- Si `auth_type == :api_key` → `:ok` (admin)
- Si `conn.assigns[:organization_id]` existe (PAT) → compara con `client.organization_id`
- Si `conn.assigns[:current_user]` existe (JWT) → busca organization memberships
- Si no matchea → `{:error, :forbidden}`

**Criterio de aceptación:**
- PAT de org ZEA validando cliente de org ZEA → `:ok`
- PAT de org Südlich validando cliente de org ZEA → `{:error, :forbidden}`
- API Key validando cualquier cliente → `:ok`

---

### T-06: Agregar ruta en router.ex

**Archivo:** `lib/thalamus_web/router.ex` (editar)

**Qué incluye:**
- Una línea en el scope `:api_auth` existente, junto a los otros endpoints de clients:
```elixir
get "/clients/:client_id/validate", OAuth2ClientController, :validate
```

**Criterio de aceptación:**
```bash
mix phx.routes | grep validate
# → GET /api/clients/:client_id/validate
```

---

### T-07: Unit tests para OAuth2ClientValidator

**Archivo:** `test/thalamus/application/oauth2_client_validator_test.exs` (nuevo)

**Setup:** `use ExUnit.Case, async: true` + `import Mox`

**Estrategia de stubbing:**
- `Application.get_env(:thalamus, ThalamusWeb.Plugs.CORS)` → stub via `Application.put_env` en setup callback con `on_exit` para restaurar
- `Application.get_env(:thalamus, ThalamusWeb.Plugs.SecurityHeaders)` → mismo patrón
- `Req.get` y `Req.post` → mock con Mox definiendo un behaviour `Thalamus.HTTPClient` o usando `Req.Test`

**Tests de coherencia de cliente:**
```
✓ run/1 con SPA perfecto → 6+ checks, todos PASS, status "valid"
✓ run/1 con cliente inactivo → client_active FAIL, detail "deactivated"
✓ run/1 con SPA + client_secret_post → auth_method FAIL, detail contiene "none"
✓ run/1 con SPA + pkce_required=false → pkce_required WARN, detail "insecure"
✓ run/1 con SPA sin authorization_code → grant_types FAIL
✓ run/1 con SPA sin redirect_uris → redirect_uris_present FAIL
✓ run/1 con backend (confidential) + client_credentials → auth_method PASS, grant_types PASS
✓ run/1 con backend + token_endpoint_auth_method=none → auth_method WARN
✓ run/1 con backend sin client_credentials → grant_types WARN
✓ run/1 con tipo :m2m → mismo comportamiento que :confidential
✓ run/1 sin openid en scopes → has_openid_scope FAIL
✓ run/1 con openid → has_openid_scope PASS
✓ run/1 con redirect_uri http:// → formato válido, sin FAIL
✓ run/1 con redirect_uri ftp:// → redirect_uri_format FAIL
✓ run/1 con redirect_uri vacío → sin FAIL de formato (no hay URIs que validar)
```

**Tests de CORS:**
```
✓ check_cors_origins/1 con CORS_ORIGINS=["http://app.zea.localhost"] y redirect_uri "http://app.zea.localhost/callback" → PASS
✓ check_cors_origins/1 con origen faltante → FAIL, detail contiene "Add to CORS_ORIGINS"
✓ check_cors_origins/1 con CORS_ORIGINS no configurado (Application.get_env retorna []) → WARN, detail "not configured"
✓ check_cors_origins/1 con 3 redirect URIs mismo origen → solo 1 check (deduplicación)
✓ check_cors_origins/1 con mixed http/https mismo host → 2 checks independientes
```

**Tests de CSP:**
```
✓ check_csp_form_action/1 con form-action que incluye http://*.zea.localhost:* → cubre app.zea.localhost (PASS)
✓ check_csp_form_action/1 con form-action que incluye http://soma.zea.localhost:* → cubre soma.zea.localhost (PASS)
✓ check_csp_form_action/1 con dominio no cubierto → WARN, detail "config/config.exs AND security_headers.ex"
✓ check_csp_form_action/1 sin CSP configurado → FAIL, detail "not configured"
✓ check_csp_form_action/1 con form-action que incluye https://*.zea.cl → cubre sudlich.zea.cl (PASS)
✓ check_csp_form_action/1 con localhost:* → cubre localhost:4000 (PASS)
✓ check_csp_form_action/1 con redirect URIs duplicadas → solo 1 WARN por dominio único
```

**Tests de endpoint health:**
```
✓ check_endpoint_health/0 con JWKS 200, authorize 302, token 400 → 3 PASS
✓ check_endpoint_health/0 con JWKS 500 → jwks_endpoint FAIL, detail "HTTP 500"
✓ check_endpoint_health/0 con authorize unreachable (Req error) → authorize_endpoint FAIL, detail "unreachable"
✓ check_endpoint_health/0 con token 200 (no esperado) → token_endpoint FAIL
✓ Todos los health checks son independientes → si JWKS falla, authorize y token siguen
```

**Tests de helpers:**
```
✓ overall_status/1 con [pass, fail, pass] → "invalid"
✓ overall_status/1 con [pass, warn, pass] → "warning"
✓ overall_status/1 con [pass, pass, pass] → "valid"
✓ overall_status/1 con [] → "valid"
✓ count_statuses/1 con [pass, fail, warn, pass] → %{pass: 2, fail: 1, warn: 1}
✓ count_statuses/1 con [] → %{pass: 0, fail: 0, warn: 0}
```

---

### T-08: Controller tests para validate/2

**Archivo:** `test/thalamus_web/controllers/api/oauth2_client_controller_test.exs` (editar — agregar describe block)

**Setup:** `use ThalamusWeb.ConnCase, async: true`

**Estrategia de fixtures:**
- Usar seeded clients: `platform_web` (id: `59991e63-852c-44e5-aee1-a761ec76eaea`, org: ZEA), `soma_service` (org: ZEA), `sudlich_app` (org: Südlich)
- Autenticación simulada vía `conn.assigns` (el `APIAuth` plug tiene modo placeholder que respeta assigns preexistentes)
- No se necesita levantar el servidor real — los health checks se stubean

**Tests:**
```
✓ GET /api/clients/:id/validate con PAT de org ZEA + cliente ZEA → 200
  - body["status"] es string "valid"|"invalid"|"warning"
  - body["summary"] tiene keys "pass", "fail", "warn"
  - body["checks"] es array con objetos {check, status}
  - body["client_id"] matchea el ID pedido
  - body["client_name"] no es nil
  - body["organization_id"] es el org_id del cliente
  - body["validated_at"] es ISO 8601

✓ GET /api/clients/:id/validate con API Key → 200
  - conn.assigns.auth_type = :api_key → ownership check permite acceso
  - Misma estructura de respuesta que con PAT

✓ GET /api/clients/:id/validate con PAT de org Südlich + cliente ZEA → 403
  - body["error"] = "Forbidden"
  - body["detail"] contiene "organization"

✓ GET /api/clients/:id/validate sin Authorization header → 401
  - El plug APIAuth halts antes de llegar al controller

✓ GET /api/clients/:id/validate con client_id no UUID → 400
  - body["error"] = "Invalid client ID format"

✓ GET /api/clients/:id/validate con UUID que no existe → 404
  - body["error"] = "Client not found"

✓ GET /api/clients/:id/validate con cliente inactivo → 200
  - Existe un check "client_active" con status "fail"
  - Los demás checks corren normalmente

✓ GET /api/clients/:id/validate con cliente SPA mal configurado → 200
  - Al menos un check con status "fail" (auth_method si usa client_secret_post)
  - body["status"] = "invalid"
```

---

### T-09: mix precommit

**Comando:** `mix precommit`

**Criterio de aceptación:**
- `mix format --check-formatted` → sin cambios pendientes
- `mix credo --strict` → sin warnings nuevos
- `mix test` → todos los tests verdes, incluyendo los nuevos
- `mix compile --warnings-as-errors` → sin warnings

---

## Dependencias Visuales

```
T-01 ──→ T-02 ──→ T-04 ──→ T-05 ──→ T-06 ──→ T-08 ──→ T-09
  │                        │
  └──→ T-03 ──────────────┘
        │
        └──→ T-07 ──────────────────────────→ T-09
```

T-07 (unit tests) y T-08 (controller tests) pueden correr en paralelo después de T-06.

---

## Notas para el desarrollador

1. **No tocar la base de datos** — este endpoint es puramente read-only
2. **Reusar `client_to_json/1`** si se necesita, aunque el validate response tiene su propio formato
3. **Usar Mox para stubs** — `Application.get_env` y `Req` deben stubbearse en tests unitarios
4. **Los checks de endpoint health son best-effort** — si Thalamus no puede llamarse a sí mismo, esos checks fallan pero los demás siguen
5. **El `base_url` para health checks** — en el docker-compose de la plataforma, Thalamus escucha en `:4000` internamente; usar `Application.get_env(:thalamus, :base_url)` que ya apunta a `http://localhost:4000` por default
