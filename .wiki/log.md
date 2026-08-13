# Log

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
