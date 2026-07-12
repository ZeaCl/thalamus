# Log

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
