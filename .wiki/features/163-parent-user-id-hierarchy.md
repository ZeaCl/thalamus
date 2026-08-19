# Jerarquía Unificada de Usuarios (parent_user_id)

- **Issue**: [#163](https://github.com/ZeaCl/thalamus/issues/163)
- **Rama**: `feature/163-parent-user-id-hierarchy`
- **Estado**: ✅ implementado (pendiente PR/merge)

## Qué se hizo
- Columna `parent_user_id` en `users` (FK self-reference a `users.id`, nullable) + índices (`parent_user_id`, `organization_id + parent_user_id`).
- `UserSchema` con `field :parent_user_id` + `belongs_to :parent`.
- Entidad de dominio `User` con `parent_user_id` (formato `user_<uuid>` en dominio, UUID crudo en DB).
- Puerto `UserRepository`: nuevos callbacks `find_by_parent/1`, `find_tree/2`, `find_agents_subtree/1`.
- Implementación postgres: árbol con BFS recursivo nivel a nivel, guard contra ciclos (`MapSet`), filtro por organización.
- `/oauth/userinfo` ahora incluye clave `reports` con los dependientes directos (`id`, `name`, `email`, `is_agent`, `role`).
- API REST `POST/PATCH /api/users` acepta/actualiza `parent_user_id`.

## Decisiones clave
- `parent_user_id` en el dominio usa prefijo `user_<uuid>` (igual que `organization_id` usa `org_`); en DB se guarda UUID crudo.
- **Contrato API**: `parent_user_id` se envía/recibe como **UUID pelado** en create/update/list/get (consistente con `organization_id`). La entrada acepta ambos formatos (pelado o `user_<uuid>`) via `normalize_parent_user_id/1`, y se normaliza a `user_<uuid>` internamente; `""` o `nil` desvincula.
- `reports[].id` en userinfo usa `user_<uuid>` (igual que `id` en la API de usuarios), distinto del `parent_user_id` pelado.
- El árbol es BFS iterativo (capa a capa) en lugar de un solo CTE: con niveles pequeños en una org es +predecible, y evita la complejidad de CTEs recursivos en Ecto. `find_tree/2` acepta `organization_id` para acotar.
- `reports` solo incluye dependientes directos (criterio de aceptación). La reseranza completa (sub-árbol) queda en `find_tree` para uso programático.
- `role` de un agente se lee de `agent_config["role"]` (omite si no existe).
- **Gotcha descubierto**: `UserSchema` tiene `@primary_key {:id, :binary_id, autogenerate: true}` y `save/1` castea sin incluir `:id`, así que el id del entity NO se respeta en INSERT (DB genera otro). En tests hay que usar el id RETORNADO por `save` (no el de `User.register`).

## Archivos modificados
- `priv/repo/migrations/20260606000000_add_parent_user_id_to_users.exs`
- `lib/thalamus/infrastructure/persistence/schemas/user_schema.ex`
- `lib/thalamus/domain/entities/user.ex`
- `lib/thalamus/application/ports/user_repository.ex`
- `lib/thalamus/infrastructure/repositories/postgresql_user_repository.ex`
- `lib/thalamus_web/controllers/oauth2/userinfo_controller.ex`
- `lib/thalamus_web/controllers/api/user_controller.ex`
- `test/thalamus/domain/entities/user_test.exs`
- `test/thalamus/infrastructure/repositories/postgresql_user_repository_test.exs`
- `test/thalamus_web/controllers/oauth2/userinfo_controller_test.exs`
- `docs/api/users.md`
- `plan/feature_163_issue_163.md`

## Errores encontrados
- Duplicación de `end`/campos en tests/controllers por ediciones encadenadas → limpiado a mano con lectura de hashes.
- Query Ecto a `parent_user_id` (`:binary_id`) rechazaba valores `user_<uuid>` → hay que pasar UUID crudo (`extract_uuid/1`) en el `where in`.

## Criterios de aceptación
- [x] Columna `parent_user_id` con FK a `users.id`
- [x] Consulta eficiente del árbol por organización y por usuario (`find_tree`, `find_by_parent`)
- [x] `/oauth/userinfo` retorna usuarios/agentes con `parent_user_id = current_user.id`

## Referencias
- https://github.com/ZeaCl/thalamus/issues/163
