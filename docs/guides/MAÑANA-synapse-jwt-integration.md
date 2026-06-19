# Synapse Integration — JWT fields + Username filter

**Status**: ⏳ Pendiente  
**Prioridad**: 🔴 Alta (Synapse MVP)  
**Fecha**: 2026-06-05  

---

## 📌 Contexto

Synapse (nuevo chat service de ZEA) necesita:
- Validar JWTs y saber si el usuario es un agente (`is_agent`)
- Resolver @menciones: buscar usuarios por username vía API

---

## Task 1: Agregar `name`, `email`, `is_agent` al JWT

### Archivos a modificar

#### A) `lib/thalamus/application/use_cases/generate_tokens.ex`

En el flujo **authorization_code** (línea ~153), el `user` ya es `%User{}` completo. Agregar los campos:

```elixir
# authorization_code — agregar a la llamada generate_jwt_access_token:

access_token =
  generate_jwt_access_token(%{
    user_id: user.id,
    client_id: client_id_string(client),
    scope: Enum.join(scopes, " "),
    expires_in: @access_token_ttl,
    aud: client_id_string(client),
    # ↓ NUEVO
    name: user.name,
    email: Email.to_string(user.email),
    is_agent: user.is_agent
  })
```

En el flujo **refresh_token** (línea ~193), `stored_token` solo tiene `user_id`. Cargar el usuario del repositorio:

```elixir
# refresh_token — agregar before generate_jwt_access_token:

{:ok, user} = get_user(stored_token.user_id, deps)

access_token =
  generate_jwt_access_token(%{
    user_id: stored_token.user_id,
    client_id: client_id_string(client),
    scope: Enum.join(scopes_list, " "),
    expires_in: @access_token_ttl,
    aud: client_id_string(client),
    # ↓ NUEVO
    name: user.name,
    email: Email.to_string(user.email),
    is_agent: user.is_agent
  })
```

⚠️ Nota: en refresh_token, `stored_token.user_id` puede ser nil (client_credentials). Manejar ese caso.

#### B) `lib/thalamus/infrastructure/jwt_signer.ex`

Agregar los nuevos claims al JWT generado:

```elixir
# En sign_access_token/1, después de los claims existentes:

extra =
  case Map.get(claims_map, :name) do
    nil -> extra
    name -> Map.put(extra, "name", name)
  end

extra =
  case Map.get(claims_map, :email) do
    nil -> extra
    email -> Map.put(extra, "email", email)
  end

extra =
  case Map.get(claims_map, :is_agent) do
    nil -> extra
    is_agent -> Map.put(extra, "is_agent", is_agent)
  end
```

### Resultado esperado del JWT

```json
{
  "sub": "abc123...",
  "iss": "https://auth.zea.cl",
  "aud": "platform_web",
  "iat": 1717623400,
  "exp": 1717627000,
  "jti": "jti_...",
  "scope": "openid profile",
  "client_id": "platform_web",
  "name": "Carlos Pérez",
  "email": "carlos@zea.cl",
  "is_agent": true
}
```

---

## Task 2: Filtro `username` en `GET /api/users`

### Archivos a modificar

#### A) `lib/thalamus_web/controllers/api/user_controller.ex`

Agregar el parámetro `username` en `build_filters/1`:

```elixir
# En build_filters, agregar después del bloque de organization_id:

filters =
  if username = params["username"] do
    Map.put(filters, :username, username)
  else
    filters
  end
```

#### B) `lib/thalamus/infrastructure/repositories/postgresql_user_repository.ex`

Agregar `filter_by_username/2` en el pipeline de `build_query`:

```elixir
defp build_query(filters) do
  query = from(u in UserSchema)

  query
  |> filter_by_status(filters[:status])
  |> filter_by_verified(filters[:verified])
  |> filter_by_organization(filters[:organization_id])
  |> filter_by_username(filters[:username])   # ← NUEVO
  |> order_by_field(filters[:order_by])
  |> limit_results(filters[:limit])
  |> offset_results(filters[:offset])
end

defp filter_by_username(query, nil), do: query

defp filter_by_username(query, username) when is_binary(username) do
  pattern = "%#{username}%"
  where(query, [u], ilike(u.name, ^pattern) or ilike(u.email, ^pattern))
end
```

---

## Task 3: Tests

### Tests a agregar

| Test | Archivo | Qué valida |
|------|---------|-----------|
| JWT contiene `name`, `email`, `is_agent` | `test/thalamus/application/use_cases/generate_tokens_test.exs` | Decodificar JWT y verificar nuevos claims |
| Refresh token JWT tiene los mismos claims | `test/thalamus/application/use_cases/generate_tokens_test.exs` | Ídem para refresh flow |
| `GET /api/users?username=carlos` encuentra por nombre | `test/thalamus_web/controllers/api/user_controller_test.exs` | Buscar usuario por nombre parcial |
| `GET /api/users?username=zea` encuentra por email | `test/thalamus_web/controllers/api/user_controller_test.exs` | Buscar usuario por email parcial |
| `GET /api/users?username=nonexistent` → array vacío | `test/thalamus_web/controllers/api/user_controller_test.exs` | 200 OK con array vacío |

### Tests existentes a verificar que NO se rompan

```bash
mix test test/thalamus/application/use_cases/generate_tokens_test.exs
mix test test/thalamus_web/controllers/api/user_controller_test.exs
mix test test/thalamus/infrastructure/repositories/postgresql_user_repository_test.exs
```

---

## 📁 Archivos involucrados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `lib/thalamus/application/use_cases/generate_tokens.ex` | Modificar | Agregar name/email/is_agent al JWT en auth_code y refresh_token |
| `lib/thalamus/infrastructure/jwt_signer.ex` | Modificar | Agregar claims name/email/is_agent al JWT |
| `lib/thalamus_web/controllers/api/user_controller.ex` | Modificar | Agregar filtro username |
| `lib/thalamus/infrastructure/repositories/postgresql_user_repository.ex` | Modificar | Agregar filter_by_username con ILIKE |

---

## 🔗 Dependencias

- Task 1 y Task 2 son independientes entre sí
- Task 1 (JWT) depende solo de `generate_tokens.ex` + `jwt_signer.ex`
- Task 2 (username filter) depende de `user_controller.ex` + `user_repository.ex`
- Tiempo estimado: **1-2 horas** para ambas tasks

---

## ✅ Validación final

```bash
# 1. Login y obtener JWT
TOKEN=$(curl -s -X POST http://localhost:4000/api/public/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@contoso.com","password":"SecureP@ss1"}' | jq -r '.data.token')

# 2. Decodificar JWT (sin verificar firma, solo para inspeccionar claims)
echo $TOKEN | cut -d'.' -f2 | base64 -d | jq .
# Debe mostrar: name, email, is_agent

# 3. Buscar usuario por username
curl -s "http://localhost:4000/api/users?username=carlos" \
  -H "Authorization: Bearer $TOKEN" | jq .

# 4. Buscar usuario inexistente
curl -s "http://localhost:4000/api/users?username=noexiste" \
  -H "Authorization: Bearer $TOKEN" | jq .
```
