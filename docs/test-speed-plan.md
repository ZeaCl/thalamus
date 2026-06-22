# Paso 6 — Plan de optimización de velocidad de tests

**Objetivo:** Reducir los tests de ~307s a ~60-90s
**Estado actual:** 1820 tests, 0 failures, ~307s

---

## 🔍 Diagnóstico

### Responsables del slowness

| Causa | Impacto | Explicación |
|-------|:---:|------|
| 68/85 módulos con `async: false` | 🔴 **~200s perdidos** | 80% de los tests corren secuencial. El sandbox está activo, deberían poder correr en paralelo. |
| Bcrypt sin configuración en test | 🔴 **~100s perdidos** | Cada `hash_pwd_salt` usa el default de producción (log_rounds=12). En test debería ser 4. |
| 2 `IO.puts` de debug en `login_controller_test.exs` | 🟡 molesto | Imprime basura en cada run |
| 30 tests individuales >500ms | 🟡 | La mayoría por Bcrypt, algunos por DB queries pesadas |

### Métricas de tests más lentos

```
2163ms — agent_token_repository create + delegation chain
1907ms — agent_token_repository multi-tenant isolation
1664ms — agent_token_repository count_active exclude expired
1625ms — token_controller PKCE
1620ms — token_controller refresh_token
1618ms — token_controller authorization_code
```

Todos los de >500ms son tests que hacen Bcrypt repetidas veces dentro del mismo test (crean tokens/usuarios en loop).

---

## 📋 Plan de ataque

### 6.1 — Reducir cost de Bcrypt en test `[x]`

**Archivo:** `config/test.exs`
**Riesgo:** Ninguno (solo afecta test)
**Impacto:** ~100s de reducción

```elixir
# Agregar al final de config/test.exs
config :bcrypt_elixir, log_rounds: 4
```

Bcrypt default es `log_rounds: 12` (2^12 iteraciones). Con `log_rounds: 4` (2^4 = 16 iteraciones), el hash es 256x más rápido. Para tests es perfecto — no necesitamos seguridad real.

---

### 6.2 — Activar `async: true` en módulos seguros `[ ]`

**Archivos:** ~60 test files
**Riesgo:** Bajo (el sandbox ya está activo)
**Impacto:** ~150s de reducción

#### Módulos SEGUROS para async (usan solo DB sandbox, sin estado compartido):

```
test/thalamus/domain/entities/*          (~5 archivos)
test/thalamus/domain/value_objects/*     (~8 archivos)
test/thalamus/application/use_cases/*    (~6 archivos)
test/thalamus/infrastructure/repositories/* (~8 archivos)
test/thalamus_web/controllers/api/*      (~20 archivos)
test/thalamus_web/controllers/oauth2/*   (~6 archivos)
```

#### Módulos que DEBEN quedarse `async: false`:

```
test/thalamus/infrastructure/adapters/redis_cache_adapter_test.exs  (Redis compartido)
test/integration/*                                                   (flujos multi-endpoint)
test/thalamus_web/controllers/saml_controller_test.exs              (mocks globales)
```

---

### 6.3 — Eliminar `IO.puts` de debug `[x]`

**Archivo:** `test/thalamus_web/controllers/api/login_controller_test.exs`
**Riesgo:** Ninguno
**Impacto:** Output limpio

Eliminar líneas 20-21:
```elixir
IO.puts("Setup: saved_user status = #{saved_user.status}")
IO.puts("Setup: saved_user verified_at = #{inspect(saved_user.verified_at)}")
```

---

### 6.4 — Verificar `mix precommit` `[ ]`

**Riesgo:** Medio (puede haber warnings-as-errors)
**Impacto:** Asegurar que el CI pasa

```bash
mix compile --warnings-as-errors
mix format --check-formatted
mix test
```

Si `--warnings-as-errors` falla, resolver warnings del Paso 7.

---

## 📊 Resultado esperado

| Cambio | Reducción estimada |
|--------|:---:|
| Bcrypt log_rounds: 4 | -100s |
| async: true en ~60 módulos | -150s |
| **Total estimado** | **307s → ~60s** |

---

## 🔢 Orden de ejecución

1. **6.1** — Bcrypt (1 línea, win inmediato)
2. **6.3** — IO.puts (2 líneas)
3. **6.2** — async: true (por lotes, verificando cada lote)
4. **6.4** — mix precommit (validación final)
