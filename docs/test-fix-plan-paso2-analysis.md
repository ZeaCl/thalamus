# Paso 2 — Análisis previo: Prefijo `"org_"` inconsistente

**Archivos involucrados:** 5 archivos (2 de producción + 3 de test)
**Fallos:** 8
**Riesgo:** Medio (1 bug en producción en el role repository)

---

## Raíz del problema

El ecosistema tiene **3 capas** con distintos formatos de `organization_id`:

| Capa | Formato | Ejemplo |
|------|---------|---------|
| DB (Postgres) | UUID binario puro | `"e28b1d04-d0d8-48cf-8794-bb4702044701"` |
| Domain (repos → entidades) | UUID con prefijo `"org_"` | `"org_e28b1d04-d0d8-48cf-8794-bb4702044701"` |
| JSON (controller responses) | UUID con prefijo `"org_"` | `"org_e28b1d04-..."` |

Cada repositorio debe manejar la conversión DB ↔ Domain:

```elixir
# to_domain (DB → entidad): AGREGA prefijo
"org_" <> schema.organization_id

# to_map (entidad → DB): QUITA prefijo
String.replace_prefix(entity.organization_id, "org_", "")
```

El bug: **no todos los repos siguen esta convención.**

---

## Estado de cada repositorio

| Repositorio | `to_domain` agrega `"org_"`? | `to_map` quita `"org_"`? | Consistente? |
|---|---|---|---|
| `postgresql_user_repository.ex` | ✅ Sí (línea 189) | ✅ Sí (línea 227) | ✅ |
| `postgresql_agent_token_repository.ex` | ✅ Sí (línea 230) | ✅ Sí (línea 173) | ✅ |
| `postgresql_oauth2_client_repository.ex` | ✅ Sí (vía `OrganizationId.from_string` que agrega prefix automáticamente) | ✅ Sí (línea 251) | ✅ |
| `postgresql_role_repository.ex` | ❌ **NO** (línea 174: `schema.organization_id` sin prefijo) | ✅ Sí (línea 184, fix del AI anterior) | ❌ **BUG** |

### El bug en role_repository

`to_domain` devuelve `organization_id: schema.organization_id` — el UUID puro de la DB, sin el prefijo `"org_"`. Esto causa que:

1. Las entidades `Role` tengan `organization_id` sin prefijo
2. `AssignRole.execute` compara `user.organization_id` (con prefijo, del user repo) vs `role.organization_id` (sin prefijo) → **mismatch → 403**
3. Los controllers que comparan org_id en roles fallan

---

## Fallo por fallo

### 2.1 — `agent_token_repository_test.exs` (3 fallos: líneas 132, 209, 305)

**Qué validan:** Que el repo guarda/lee tokens correctamente con el org_id correcto y aislamiento multi-tenant.

**Setup:**
```elixir
# setup_dependencies() crea org via Ecto schema → org.id = "uuid" (bare)
{client, org, user} = setup_dependencies()
token = build_agent_token(client.id, org.id, user.id)  # org.id bare
```

**Repo `to_domain`:** `"org_" <> schema.organization_id` → devuelve `"org_uuid"` con prefijo.

**Comparación:** `found_token.organization_id == org.id` → `"org_uuid" == "uuid"` → **false**

**Fix:** Agregar `"org_"` prefix a `org.id` en las comparaciones, o usar `"org_" <> org.id`.

---

### 2.2 — `oauth2_client_repository_test.exs` (1 fallo: línea 440)

**Qué valida:** Que `list/1` filtra correctamente por `organization_id`.

**Setup:**
```elixir
org_id1 = create_organization()  # → "uuid" (bare)
# Se guarda cliente con ese org, luego se lee
{:ok, org1_clients} = PostgreSQLOAuth2ClientRepository.list(%{organization_id: org_id1})
```

**Repo `to_domain`:** `OrganizationId.from_string(schema.organization_id)` → `%OrganizationId{value: "org_uuid"}` (agrega prefijo automáticamente).

**Comparación:** `OrganizationId.to_string(c.organization_id) == org_id1` → `"org_uuid" == "uuid"` → **false**

**Fix:** `"org_" <> org_id1` o comparar con `OrganizationId.from_string(org_id1)`.

---

### 2.3 — `role_controller_test.exs` (1 fallo: línea 41)

**Qué valida:** Que `POST /api/roles` crea un rol y devuelve el `organization_id` correcto.

**Setup:**
```elixir
org_id_string = OrganizationId.to_string(org.id)  # "org_uuid" (con prefijo)
assert role["organization_id"] == org_id_string
```

**Controller:** Lee el role de la DB → `to_domain` devuelve `organization_id` sin prefijo → JSON tiene UUID puro.

**Comparación:** `"uuid" == "org_uuid"` → **false**

**Fix:** Una vez arreglado `to_domain` del role_repository, el controller devolverá `"org_uuid"` y la comparación funcionará. Mientras tanto, ajustar el test.

---

### 2.4 — `user_role_controller_test.exs` (1 fallo: línea 21)

**Qué valida:** Que `POST /api/users/:user_id/roles` asigna un rol a un usuario.

**Error:** 403 `"organization_mismatch"`.

**Causa:** `AssignRole.execute` compara `user.organization_id == role.organization_id`:
- `user` viene del user_repo → tiene prefijo `"org_"`
- `role` viene del role_repo → **no tiene prefijo** (bug en `to_domain`)

**Fix:** Arreglar `to_domain` en el role_repository para que agregue el prefijo, consistente con los demás repos.

---

### 2.5 — `role_controller.ex` (producción, líneas ~98 y ~190)

No es un fallo de test directo, pero el AI anterior ya intentó fixear esto en el controller:
```elixir
# validate_organization
role_org = String.replace_prefix(to_string(role.organization_id), "org_", "")
conn_org = String.replace_prefix(to_string(organization_id), "org_", "")
if role_org == conn_org do ...
```

Este fix del controller es un **workaround**. La raíz es el `to_domain` del role_repository. Si arreglamos el repo, este workaround en el controller se vuelve redundante (pero no daña).

---

## Estrategia de fix

### Fix principal (producción): `role_repository.ex` — `to_domain`

Cambiar línea 174:
```elixir
# Antes
organization_id: schema.organization_id,

# Después  
organization_id: if(schema.organization_id, do: "org_" <> schema.organization_id, else: nil),
```

Esto hace que el role_repository sea consistente con user_repository y agent_token_repository.

### Fixes en tests:

| Archivo | Cambio |
|---------|--------|
| `agent_token_repository_test.exs` (3 lugares) | `org.id` → `"org_" <> org.id` en comparaciones |
| `oauth2_client_repository_test.exs` (1 lugar) | `org_id1` → `"org_" <> org_id1` en comparación |
| `role_controller_test.exs` (1 lugar) | Se arregla solo al fixear `to_domain` |
| `user_role_controller_test.exs` (1 lugar) | Se arregla solo al fixear `to_domain` |
| `role_controller.ex` (opcional) | El workaround actual puede quedarse o limpiarse |
