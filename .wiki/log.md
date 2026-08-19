# Log

## [2026-08-13] fix | #160 device flow verification_uri con :80 → ERR_SSL_PROTOCOL_ERROR
- Síntoma: `build_verification_uri/1` generaba `https://auth.zea.cl:80/oauth/activate` (HTTPS + puerto 80) cuando `FORCE_SSL` no está en prod
- Fix defensivo en código: omitir puerto cuando `public_port`/`conn.port` es 80/443 (igual que discovery)
- Tests de regresión nuevos: `device_controller_test.exs` (no existía)
- PR #161 mergeado (squash). Pendiente fix raíz: setear `FORCE_SSL=true` en env de prod (zea-cicd/infra)
- Follow-up de review: #162 (centralizar construcción de URLs absolutas)

## [2026-08-13] chore | cleanup CLI test infra + dead use case (#154)
- Removed CLI unit-test machinery (`*.test.js`, `cli/test/`, `extract-test-coverage.cjs`, `cli.test.coverage`) — the CLI is tested by running commands (E2E `scripts/test-cli.sh`)
- Removed legacy `test/cli/*.sh` suite + `scripts/smoke-test-cli.sh` (superseded)
- Removed now-unused `AuthenticateUser` use case + `AuthenticationRequest` DTO (no HTTP caller after removing `/api/public/login`)
- Updated `mix.exs`, `cli/package.json`, `manifest.json`, and docs to match

## [2026-08-13] fix | #154 remove stateless login tokens + userinfo JWKS fallback
- Root cause: `/api/public/login` issued a stateless JWT not persisted in `tokens`, breaking `/oauth/userinfo`
- Removed `POST /api/public/login` (`LoginController`), its route, its tests, and `JwtSigner.sign_refresh_token/1`
- Removed CLI direct login (`handleDirectLogin` + `login --email/--password`); kept browser PKCE and device flow
- Extracted JWKS verification into `JwtSigner.verify_access_token/1`; `AuthenticateToken` delegates to it; `UserinfoController` adds the same fallback
- `mix test` → 1906 tests, 0 failures; CLI coverage 72/72

## [2026-08-03] fix | #147 zea-thalamus login usa puerto aleatorio → invalid redirect_uri
- `server.listen(0)` elegía puerto aleatorio, pero Thalamus solo acepta redirect URIs registradas
- Fix: cambiado a `server.listen(4005)`, puerto que ya está en la whitelist del client "Thalamus CLI"
- Archivo: `cli/src/lib/client.js` línea 201

## [2026-07-26] fix | #119 seeds.exs sobreescribe members en cada deploy
- seeds corría en cada deploy (vía release.ex migrate) y reseteaba organization.members y current_user_count
- Fix: guardia is_nil/empty antes de los Repo.update! de ZEA y Südlich
- PR #120 mergeado a main
- OrganizationId value object aceptaba valores no-UUID (ej. "org1") que pasaban validación pero fallaban en Ecto dump → 500
- Fix: valid_uuid?/1 en validate_format/1 rechaza org IDs sin formato UUID → 400 Bad Request
- PR #118 mergeado a main

## [2026-07-25] fix | #107 secret list muestra IDs + #108 bug infraestructura tests CLI
- `secret list` ahora muestra el ID completo (UUID) de cada secret para usar con `secret delete`
- Fix: `options = {}` default en list/create/resolve evita crash `Cannot read properties of undefined`
- Fix: URL sin `?` vacío cuando no hay filtros en list
- Tests: `mock.method(process, 'exit')` movido a `beforeEach`, `console.error` captura output
- Descubierto bug sistémico: misma falla en 13/15 archivos de test CLI → issue #108

## [2026-07-23] feat | #39 CLI E2E + OAuth2 ROPC + optimización pipelines
12 tests E2E pasando con OAuth2 password grant. Fixes: Mix.env() en PAT generator, organization_id en token_data, orden de tests. Pipelines optimizados: concurrency, cache unificada, composite action, Docker compartido, script test-cli.sh. Issues #42, #44-#48, #55-#63, #64-#73 cerrados.

## [2026-07-15] feat | #42 --zea-discover flag para dynamic command discovery
Flag `--zea-discover` agregado en `cli/bin/zea-thalamus.js`. Expone 64 comandos como JSON para que `zea-cli` los descubra dinámicamente (smoke testing, help, validación). Mismo patrón que `zea-soma`.

## [2026-07-12] feat | #14 Fase 1 defensiva: domain_roles siempre presente + authz_source
`domain_roles` siempre incluido (vacío `[]` si no hay roles). Claim `authz_source: "domain_roles"` explícito. `api_auth.ex` fallback a `domain_roles[0].org_id`. `organization_id` deprecated en docs. 1869 tests, 0 fallos nuevos.

## [2026-07-12] fix | #9 JwtSigner.fetch_domain_roles fix aplicado
Fix: `Ecto.UUID.cast` explícito antes de la query + rescue específico (`DBConnection.ConnectionError`, `OwnershipError`) + `Logger.warning`. Tests: login_controller_test.exs ya cubría domain_roles (2 tests), 1869 tests total, 0 fallos nuevos. Sub-issues #9 y #13 cerrados.

## [2026-07-12] docs | #11 domain_roles documentado en docs/, wiki, y skill
`docs/api/authentication.md`: JWT Claims con domain_roles. `docs/api/domains.md`: nota relación JWT. `docs/architecture/overview.md`: UserDomainRole schema. `.wiki/features/jwt-domain-roles.md`. Skill thalamus-integration actualizada. Sub-issues #10, #11, #12 cerrados.

## [2026-07-12] bug | #6 Investigación domain_roles — root cause identificada
`JwtSigner.fetch_domain_roles/1` silencia errores de query con `rescue _ -> []`. Si la query a `user_domain_roles` falla, el JWT sale sin `domain_roles`. Sub-issues #9-#13 creados. Documentación en `docs/` (authentication, domains, architecture) y `.wiki/features/jwt-domain-roles.md`.

## [2026-07-12] infra | Wiki operativo interno creado
Estructura `.wiki/` replicada del patrón südlich: index, log, rules, features/, integrations/. CLAUDE.md actualizado con sección de mantenimiento de wiki.

## [2026-07-12] issue | #8 Seeds: agregar user_domain_roles para desarrollo local
Issue creado. Seeds actuales no incluyen `user_domain_roles`, necesarios para probar login multi-tenant en desarrollo.

## [2026-07-08] bug | #6 JWT de /api/public/login no incluye domain_roles
Reportado por integración con fm_funds. El JWT emitido en login no incluye los `domain_roles` del usuario, lo que rompe la autorización multi-tenant en servicios downstream que validan roles por dominio.

## [pre-2026-07] feat | v1.0.0-rc1 — OAuth2 + OIDC + MFA + Multi-tenancy
Release candidate con: Authorization Code + PKCE, Client Credentials, Refresh Token, Token Introspection (RFC 7662), Revocation (RFC 7009), OIDC userinfo, TOTP MFA, RBAC, agent tokens (feature-flagged), rate limiting, CORS, security headers.

## [2026-07-27] fix | #125 Device flow no leía config.apiUrl
- **Issue**: #125
- **Ramas**: fix/issue-125-device-flow-apiurl, fix/issue-125-refactor-apiurl
- handleDeviceLogin, handleLogin, handleDirectLogin no incluían config.apiUrl en fallback
- Fix inicial: agregar loadConfig() + config.apiUrl en los 3 handlers
- Refactor: extraer resolveApiUrl() helper, corregir prioridad (options.url > config.apiUrl)
- PRs: #126, #127

## [2026-07-27] fix | #128 zeaFetch no enviaba Host header a .zea.localhost
- **Issue**: #128
- **Rama**: fix/issue-128-zeafetch-host-header  
- zeaFetch resolvía .zea.localhost → 127.0.0.1 pero sin Host header
- Caddy necesita Host para rutear → devolvía body vacío (content-length: 0)
- Fix: agregar Host header automáticamente al resolver .zea.localhost
- Afectaba todos los endpoints .zea.localhost, no solo device login
- PR: #129

## [2026-07-27] feat | #163 Jerarquía Unificada de Usuarios vía parent_user_id
- **Issue**: #163
- **Rama**: feature/163-parent-user-id-hierarchy
- Columna `parent_user_id` (FK self a `users.id`, nullable) + índices
- `find_by_parent/1`, `find_tree/2` (BFS + guard ciclos + filtro org), `find_agents_subtree/1` en el puerto/repo
- `/oauth/userinfo` ahora expone `reports` (dependientes directos con `role` desde `agent_config`)
- API REST acepta `parent_user_id` en create/update
- TDD: domain, repo (round-trip + tree) y controller. Suite completa: 1903 tests / 0 failures
- Detalle en `.wiki/features/163-parent-user-id-hierarchy.md`

## [2026-07-27] ops | GCP pipeline: GitHub Actions ya no usados en thymos
- Confirmado: la migración CI/CD a GCP es parte del epic `ZeaCl/zea-cicd#35` (pasos #37 pipeline GCP y #38 migrar Thalamus).
- `.github/workflows/` en thymos sigue activo y falla en PRs por billing de GH Actions (no es gate real).
- Se creó `AGENTS.md` en este repo indicando que el CI/CD es GCP.
- Issue de seguimiento/cleanup nuevo: `ZeaCl/zea-cicd#46` (con cross-links a #37 y #38).

## [2026-08-19] cli + e2e | Validación de jerarquía (parent_user_id) desde zea-thalamus CLI
- Actualicé la CLI (`cli/src/commands/user.js`, `auth.js`) para exponer la jerarquía del issue #163:
  - `user create --parent-user-id <id>` (acepta UUID pelado o `user_<uuid>`)
  - `user update <id> --parent-user-id <id>` ; `""` desvincula
  - `user show`/`user list` muestran parent_user_id
  - `whoami` lista `Reports:` (dependientes directos vía `/oauth/userinfo`)
- Validación e2e REAL contra servidor dev en `localhost:4101` con la migración aplicada:
  - Se creó boss humano + agente hijo con `--parent-user-id` → `user show` mostró Parent correcto
  - `whoami` del boss listó el agente en `Reports:` 
  - `user update --parent-user-id ""` desvinculó; re-vincular con UUID pelado OK
- Gotchas de entorno dev (ajenos a la feature): token guardado en CLI no servía → generé access token directo a DB dev; una org tenía `plan_type='professional'` (inválido) que rompía `/oauth/userinfo` → corregido a `enterprise`.
- Docs: `docs/cli/CLI_COMMANDS.md` actualizado.

## [2026-08-19] ops | Issue ZeaCl/zea-cicd#47 — cómo publicar la CLI (@zea.cl/thalamus) a npm
- La CLI local de thymos quedó desactualizada respecto a los cambios de jerarquía (#163).
- Se creó pregunta al equipo CI/CD: `ZeaCl/zea-cicd#47` para que indiquen el flujo oficial de publicación (tag v* / bump / pipeline GCP vs CodeBuild legacy).
- Cross-link en PR #164.
- La skill `zea-deploy` documenta: bump versión en package.json → merge a main → tag v* → CodeBuild `zea-thalamus-npm` publica a npmjs (@zea.cl/thalamus). A confirmar por el equipo por la migración a GCP.

## [2026-08-19] ops | Issue ZeaCl/zea-cicd#48 — inconsistencias en skill zea-cli-publish
- Se creó la skill `zea-cli-publish` para guiar publicación npm (@zea.cl/*).
- Revisión crítica detectó inconsistencias: (1) describe pipeline AWS CodeBuild pero AWS se apaga → debe ser GCP; (2) lista `@zea.cl/create-cerebelum` pero el proyecto es `cerebelum`; (3) mezcla CLI vs SDK (soma se publica desde `cli/`, no `sdk/`); + otras (catálogo vs terraform npm_services, binario global `zea` no `zea-cli`).
- Se documentó en issue para que el equipo verifique/corrija: ZeaCl/zea-cicd#48.
- NO se editó la skill a mano (decisión del usuario) — se dejó la verificación al equipo.
