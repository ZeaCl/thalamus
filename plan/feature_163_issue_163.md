# Plan — [FEAT] Jerarquía Unificada de Usuarios (Humanos + Agentes IA) vía `parent_user_id`

- **Issue**: https://github.com/ZeaCl/thalamus/issues/163
- **Rama**: `feature/163-parent-user-id-hierarchy`
- **Estado**: 🔄 en progreso
- **Estrategia**: TDD — escribir tests unitarios e integración primero, verlos fallar, e implementar.

> Este plan es la fuente de verdad de las subtareas. Se marcan `[x]` conforme se completan.

---

## ✅ Checklist de subtareas

### Fase 0 — Test database & baseline
- [x] Crear rama `feature/163-parent-user-id-hierarchy`
- [x] Escribir este plan con subtareas (checklist)
- [x] Correr `mix test` baseline para confirmar suite verde antes de tocar código

### Fase 1 — Tests unitarios (TDD, primero en fallar)

- [x] 1.1 Test **domain entity** `User` → usa/carrea `parent_user_id` en `new/1`, `register/2`, `register_agent/4`
- [x] 1.2 Test **domain entity** `User` → `agent_config` expone `role` para armar `reports`
- [x] 1.3 Test **schema** `UserSchema` → `create_changeset`/`update_changeset` castean `parent_user_id` (nullable)
- [x] 1.4 Test **repo (unit)** `find_by_parent/1` → devuelve hijos directos
- [x] 1.5 Test **repo (unit)** tree recursivo → sub-árbol multi-nivel (capa a capa)
- [x] 1.6 Test **repo (unit)** `find_agents_subtree/1` → solo agentes subordinados

### Fase 2 — Tests de integración (fallando primero)

- [x] 2.1 Test integración: `parent_user_id` persistido y leído correctamente via repo (round-trip)
- [x] 2.2 Test integración: tree recursivo por organización
- [x] 2.3 Test controller: `/oauth/userinfo` incluye `reports` (agentes/hijos) cuando existen
- [x] 2.4 Test controller: `/oauth/userinfo` omite/`[]` `reports` cuando no hay dependientes

### Fase 3 — Implementación

- [x] 3.1 Migración `add_parent_user_id_to_users` (FK a `users.id`, nullable) + índices
- [x] 3.2 `UserSchema`: agregar `parent_user_id` field + relación `belongs_to :parent`
- [x] 3.3 `User` entidad: agregar `parent_user_id` a tipo/struct/`new/1`/constructores
- [x] 3.4 Puerto `UserRepository`: callbacks `find_by_parent/1`, `find_agents_subtree/1`
- [x] 3.5 Impl `PostgreSQLUserRepository`: `find_by_parent`, tree recursivo-eficiente, `find_agents_subtree`
- [x] 3.6 Mapeo `schema_to_entity`/`entity_to_schema` con `parent_user_id` (prefijo `user_`)
- [x] 3.7 `UserinfoController`: agregar `reports` al JSON
- [x] 3.8 API REST: aceptar `parent_user_id` en create/update de usuario

### Fase 4 — Documentación

- [ ] 4.1 Actualizar `docs/api/users.md` (parámetro `parent_user_id`, campo `reports` en userinfo)
- [ ] 4.2 Actualizar `.wiki/log.md`
- [ ] 4.3 Crear `.wiki/features/163-parent-user-id-hierarchy.md`
- [ ] 4.4 Actualizar `.wiki/index.md`

### Fase 5 — Quality checks & CI

- [ ] 5.1 `mix format --check-formatted`
- [ ] 5.2 `mix compile --warnings-as-errors`
- [ ] 5.3 `mix credo --strict`
- [ ] 5.4 `mix test` completo verde
- [ ] 5.5 `mix ecto.migrations` aplicadas

### Fase 6 — Commit & PR

- [ ] 6.1 Commit con cambios (mensajes tipo conventional commits por fase)
- [ ] 6.2 Abrir PR hacia `main`
- [ ] 6.3 Code review (skill zea-code-review) antes de mergear

---

## Notas de diseño

- `parent_user_id` es UUID crudo en DB (mismo esquema que `organization_id`), con prefijo `"user_"` en capa de dominio/repo.
- `reports` en userinfo = usuarios con `parent_user_id = current_user.id`.
- `role` de un agente se lee de `agent_config["role"]` si existe (omitir si no).
- Resolución de árbol: CTE recursivo / BFS iterativo con guard contra ciclos, filtrando por `organization_id` cuando aplique.
- Criterios de aceptación del issue:
  1. [ ] Columna `parent_user_id` + FK a `users.id`
  2. [ ] Consulta eficiente del árbol por organización y por usuario
  3. [ ] `/oauth/userinfo` retorna usuarios/agentes con `parent_user_id = current_user.id`
