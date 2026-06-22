# Paso 1 — Análisis previo: HTTP Status Codes y JSON structure mismatch

**Archivos involucrados:** 3 archivos de test + 1 bug en producción
**Fallos:** 6
**Riesgo:** Bajo a Medio (1 bug de producción detectado)

---

## 1.1 — `user_controller_test.exs:236` — Email duplicado retorna 409, no 400

### El problema en partes

**Parte A — Lo que el test espera:**
```elixir
# test/thalamus_web/controllers/api/user_controller_test.exs:251
assert %{"error" => _} = json_response(conn, 400)
```

**Parte B — Lo que el controller realmente hace:**
```elixir
# lib/thalamus_web/controllers/api/user_controller.ex:156
status =
  if has_unique_constraint_error?(changeset, :email), do: :conflict, else: :bad_request
conn |> put_status(status) |> json(...)
```
El controller distingue explícitamente: error de validación → 400, email duplicado → 409 Conflict.

**Parte C — Quién tiene razón:**
El controller. HTTP RFC 7231: 409 Conflict es el código correcto cuando el request entra en conflicto con el estado actual del recurso (email ya existe).

### Fix

Cambiar `400` → `409` en el test. Sin riesgo.

---

## 1.2 — `registration_controller_test.exs:47` — Mensaje de error cambió

### El problema en partes

**Parte A — Lo que el test espera:**
```elixir
assert html_response(conn, 200) =~ "Email address already registered"
```

**Parte B — Lo que el controller pone en el flash:**
```elixir
# lib/thalamus_web/controllers/registration_controller.ex:53
|> put_flash(:error, "Email address already registered. Please sign in instead.")
```
El mensaje ahora es más largo: `"... Please sign in instead."`

**Parte C — El `=~` matchea substrings:**
`"Email address already registered" =~ "Email...Please sign in instead."` → **true**. El problema NO es el texto.

**Parte D — El verdadero problema:**
El test hace `html_response(conn, 200)` y el HTML devuelto es el layout completo de la app. El flash de Phoenix se guarda en la sesión y requiere un redirect o el layout que lo renderice. En Phoenix 1.8, `<.flash_group>` está en `Layouts.app`. Si el registration controller hace `render` (no `redirect`), el flash del request actual **no se renderiza automáticamente**.

Hay que verificar el flujo: ¿el controller hace `redirect` después de error o `render`?

### Fix (requiere verificación previa)

Opción A: Verificar qué retorna el controller y ajustar el test para buscar en `conn.assigns.flash` o usar `get_flash(conn)`.
Opción B: Si el controller hace render, verificar que el template incluya `@flash`.

---

## 1.3 — `oauth2_client_controller_test.exs` (4 fallos)

### 1.3.1 — Test línea 134: `creates new OAuth2 client`

**Problema:** El test espera keys que no existen en la respuesta real.

| Esperado (test) | Real (controller) |
|---|---|
| `"allowed_scopes"` | `"scopes"` |
| `"secret"` | `"client_secret"` |

El controller en `client_to_json/1` usa `:scopes` (no `:allowed_scopes`) y en la acción `create` agrega `:client_secret` (no `:secret`).

**Fix:** Renombrar keys en el test. Sin riesgo.

### 1.3.2 — Test línea 166: `creates client with default grant types and scopes`

**Problema:** Igual que arriba: el test espera `"allowed_scopes"` pero el controller retorna `"scopes"`.

**Fix:** Cambiar `"allowed_scopes"` → `"scopes"`. Sin riesgo.

### 1.3.3 — Test línea 208: `returns error with invalid grant type`

**Problema:** El test envía `allowed_grant_types: ["invalid_grant"]` y espera **400**, pero el controller retorna **201 Created** exitosamente.

**Causa raíz — BUG EN PRODUCCIÓN:**

El test manda:
```elixir
|> post(~p"/api/clients", %{
    allowed_grant_types: ["invalid_grant"],  # ← esta key
    ...
})
```

Pero el controller (`create_client`) lee:
```elixir
grant_type_strings = params["grant_types"] || ["authorization_code", "refresh_token"]
#                          ^^^^^^^^^^^^^^ — key distinta
```

Como `params["grant_types"]` es `nil` (la key real es `"allowed_grant_types"`), el controller usa los defaults silenciosamente y crea el cliente con `grant_types = ["authorization_code", "refresh_token"]`.

**Fix:** Hay 2 sub-problemas:

1. **Sub-fix A (test):** Cambiar `allowed_grant_types` → `grant_types` en el body del request. Así el controller recibe el valor y puede validarlo.

2. **Sub-fix B (controller - PRODUCCIÓN):** El controller DEBE validar los grant types y rechazar valores inválidos. Actualmente si `params["grant_types"]` tiene strings inválidos, `String.to_existing_atom` lanza `ArgumentError`. Pero si la key es incorrecta, silenciosamente usa defaults. Hay que:
   - Aceptar AMBAS keys: `grant_types` y `allowed_grant_types` (retrocompatibilidad)
   - O estandarizar la API a una sola key

**Riesgo medio** — requiere tocar el controller.

### 1.3.4 — Test línea 395: `updates allowed scopes`

**Problema:** El test envía `allowed_scopes: ["zea:read", "write", "admin"]`, espera `"api:admin" in scopes`, pero la respuesta contiene `["openid"]` (scopes originales sin modificar).

**Causa raíz — BUG EN PRODUCCIÓN:**

El test manda:
```elixir
|> patch(~p"/api/clients/#{id}", %{allowed_scopes: ["zea:read", "write", "admin"]})
```

Pero `apply_updates` en el controller lee:
```elixir
case params["scopes"] do   # ← busca "scopes", no "allowed_scopes"
  nil -> client
  scope_strings -> ...
end
```

Como `params["scopes"]` es `nil`, el update de scopes **no se aplica**. El cliente queda con sus scopes originales (`["openid"]`).

**Fix:** 2 sub-problemas:

1. **Sub-fix A (test):** Cambiar `allowed_scopes` → `scopes` en el body del request.

2. **Sub-fix B (test):** El test espera `"api:admin"` pero manda `"admin"`. La normalización de scopes agrega el prefijo `"api:"`. Hay que verificar qué scopes están configurados como válidos. Si `"admin"` se normaliza a `"api:admin"`, el test debe esperar el valor normalizado. Si no, ajustar.

3. **Sub-fix C (controller - PRODUCCIÓN):** Igual que 1.3.3 — el controller debe aceptar `allowed_scopes` como alias de `scopes` para retrocompatibilidad.

**Riesgo medio** — requiere tocar el controller.
