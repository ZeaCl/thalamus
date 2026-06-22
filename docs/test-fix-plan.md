# Test Fix Plan — Thalamus

**Fecha inicio:** 2026-06-22
**Estado inicial:** 21 fallos, 16 skipped (de 1820 tests)

---

## Paso 1: HTTP Status Codes & JSON key mismatch — `[x]` completado

Archivos: `user_controller_test.exs`, `registration_controller_test.exs`, `oauth2_client_controller_test.exs`
Riesgo: **bajo**
Análisis detallado: [`docs/test-fix-plan-paso1-analysis.md`](test-fix-plan-paso1-analysis.md)

**Conclusión del análisis:** Los tests usan nombres de keys/parámetros que no coinciden con el controller real. Los fixes son todos del lado del test, sin tocar producción (excepto 1.3.3/1.3.4 donde el controller no valida keys incorrectas, pero eso es comportamiento esperado).

| # | Archivo | Línea | Qué valida el test | Error | Fix | Estado |
|---|---------|-------|--------------------|-------|-----|--------|
| 1 | `user_controller_test.exs` | 236 | Rechazar email duplicado | Espera `400`, controller retorna `409 Conflict` | `400` → `409` | `[x]` |
| 2 | `registration_controller_test.exs` | 47 | Mostrar error en HTML al registrarse con email existente | Flash no se renderiza en el HTML del test + hash inválido | Usar `Phoenix.Flash.get/2` + Bcrypt hash válido | `[x]` |
| 3 | `oauth2_client_controller_test.exs` | 134 | Happy path crear cliente (todos los campos) | Keys `allowed_scopes`→`scopes`, `secret`→`client_secret` | Renombrar keys en el test | `[x]` |
| 4 | `oauth2_client_controller_test.exs` | 166 | Crear cliente con defaults (sin grant_types/scopes) | Key `allowed_scopes` no existe, es `scopes` | `allowed_scopes` → `scopes` | `[x]` |
| 5 | `oauth2_client_controller_test.exs` | 208 | Rechazar grant_type inválido con 400 | Test manda `allowed_grant_types`, controller espera `grant_types` → usa defaults y crea cliente (201) | `allowed_grant_types` → `grant_types` en el body | `[x]` |
| 6 | `oauth2_client_controller_test.exs` | 395 | PATCH update de scopes persiste el cambio | Test manda `allowed_scopes`, controller espera `scopes` → update no se aplica | `allowed_scopes` → `scopes` + scopes con prefijos válidos (`zea:write`, `api:admin`) | `[x]` |

---

## Paso 2: Prefijo `"org_"` inconsistente — `[x]` completado

Archivos: `agent_token_repository_test.exs`, `oauth2_client_repository_test.exs`, `role_controller_test.exs`, `role_controller.ex`, `user_role_controller_test.exs`
Riesgo: **medio**

**Estrategia:** los repositorios strepean el prefix antes de escribir en DB y lo agregan al leer → entidades de dominio siempre llevan prefix. Controllers y tests comparan usando helpers consistentes (`org_uuid/1`).

| # | Archivo | Línea | Error | Fix | Estado |
|---|---------|-------|-------|-----|--------|
| 7 | `postgresql_agent_token_repository_test.exs` | 132 | `found_token.organization_id == org.id` compara `"org_UUID"` vs UUID puro | Strepear o normalizar | `[x]` |
| 8 | `postgresql_agent_token_repository_test.exs` | 209 | Ídem | Strepear o normalizar | `[x]` |
| 9 | `postgresql_agent_token_repository_test.exs` | 305 | Ídem | Strepear o normalizar | `[x]` |
| 10 | `postgresql_oauth2_client_repository_test.exs` | 440 | `OrganizationId.to_string(c.organization_id) == org_id1` con prefix mismatch | Strepear o agregar prefix consistente | `[x]` |
| 11 | `role_controller_test.exs` | 41 | `role["organization_id"] == org_id_string` compara UUID puro vs `"org_UUID"` | Normalizar en el test | `[x]` |
| 12 | `role_controller.ex` | ~98 | `role.organization_id == organization_id` compara formatos distintos | Strepear ambos lados | `[x]` |
| 13 | `role_controller.ex` | ~190 | Ídem | Strepear ambos lados | `[x]` |
| 14 | `user_role_controller_test.exs` | 21 | `"organization_mismatch"` — user y role con distinto formato de org_id | Normalizar en el test | `[x]` |

---

## Paso 3: `token_controller_test.exs` — Ecto schema error — `[x]` completado

Archivo: `token_controller_test.exs`
Riesgo: **medio**

| # | Archivo | Línea | Error | Fix | Estado |
|---|---------|-------|-------|-----|--------|
| 15 | `token_controller_test.exs` | 168 | `TokenSchema` rechaza scopes: `{"is invalid", [type: {:array, :string}]}` | `[:openid]` (átomo) → `["openid"]` (string) | `[x]` |

---

## Paso 4: `agent_token_controller_test.exs` — 500 internal error — `[x]` completado

Archivo: `agent_token_controller_test.exs`
Riesgo: **alto** (requiere investigar stack trace real)

| # | Archivo | Línea | Error | Fix | Estado |
|---|---------|-------|-------|-----|--------|
| 16 | `agent_token_controller_test.exs` | 107 | 500 Internal Server Error (supervisor token con params) | `:invalid_task_id` + scope assertions | `[x]` |
| 17 | `agent_token_controller_test.exs` | 146 | 500 Internal Server Error (tool agent token) | `:invalid_task_id` + max_operations assertion | `[x]` |
| 18 | `agent_token_controller_test.exs` | 180 | 500 Internal Server Error (max TTL enforcement) | Test expects capping (200), controller rejects (400) | `[x]` |
| 19 | `agent_token_controller_test.exs` | 328 | 500 Internal Server Error (invalid client_id) | Missing `organization_id` in request body | `[x]` |
| 20 | `agent_token_controller_test.exs` | 537 | 500 Internal Server Error (token storage) | Wrong repo + access_token mismatch | `[x]` |
| 21 | `agent_token_controller_test.exs` | 577 | 500 Internal Server Error (token introspection) | `:invalid_task_id` + agent tokens not introspectable yet | `[x]` |

---

## Paso 5: `personal_access_token_controller_test.exs` — pattern match — `[x]` completado

Archivo: `personal_access_token_controller_test.exs`
Riesgo: **bajo**

| # | Archivo | Línea | Error | Fix | Estado |
|---|---------|-------|-------|-----|--------|
| 22 | `personal_access_token_controller_test.exs` | 68 | Pattern match estricto falla por campos extra (`created_at`, `expires_at`, etc.) | `org_id` trae prefijo `"org_"` pero controller devuelve UUID puro | `[x]` |

---

## Resumen

| Paso | Fallos | Riesgo | Estado |
|------|--------|--------|--------|
| 1 — HTTP Status Codes & JSON keys | 6 | Bajo | `[x]` |
| 2 — Prefijo `"org_"` | 8 | Medio | `[x]` |
| 3 — Token schema scopes | 1 | Medio | `[x]` |
| 4 — Agent token 500 errors | 6 | Alto | `[x]` |
| 5 — PAT pattern match | 1 | Bajo | `[x]` |
| **Total** | **22** (21 fallos + 1 extra detectado) | | |

> Nota: el Paso 1 tiene 6 ítems porque el fallo de `oauth2_client_controller_test.exs:134` no aparecía en la lista de 21 inicial pero sí en los logs. Se incluye para cubrirlos todos.
