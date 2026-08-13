# /oauth/userinfo 401 para JWT stateless de login

- **Issue**: #154
- **Rama**: (sin rama — fix directo)
- **Estado**: ✅ completado (tests pasando localmente)

## Qué se hizo

Alinear `UserinfoController` con `AuthenticateToken`: `/oauth/userinfo` ahora acepta
los JWT stateless emitidos por `POST /api/public/login` (client_id `thalamus_api`),
validando la firma vía JWKS cuando el token no está en la tabla `tokens`.

## Root cause

`POST /api/public/login` emite un JWT **stateless** (RS256, `client_id: thalamus_api`)
que NO se persiste en `tokens`. El plug `AuthenticateToken` (pipeline `/api/*`) ya
contemplaba este caso con fallback JWKS, pero `UserinfoController` validaba únicamente
con `ValidateToken.execute` → `PostgreSQLTokenRepository.find/1` → `token not found in DB` → 401.

Resultado: el mismo token funcionaba en `/api/organizations` pero fallaba en `/oauth/userinfo`.

## Decisiones clave

- **Reutilizar la verificación JWKS**: extraje la lógica a `JwtSigner.verify_access_token/1`,
  `validate_claims/1`, `jwt_format?/1` y `thalamus_api_jwt?/1` para no duplicar código.
- **`AuthenticateToken` delega en `JwtSigner`** (single source of truth), conservando sus
  funciones públicas (`jwt_format?`, `thalamus_api_jwt?`, `validate_jwt_claims`) para
  compatibilidad con tests existentes.
- **Fallback en `UserinfoController`**: si `ValidateToken` devuelve `valid: false` y el token
  es un JWT `thalamus_api` con firma válida y `exp` no vencido, se usa `sub` (normalizado sin
  prefijo `user_`) como `user_id` y se continúa el flujo normal.

## Archivos modificados

- `lib/thalamus/infrastructure/jwt_signer.ex` — `verify_access_token/1`, `validate_claims/1`, `jwt_format?/1`, `thalamus_api_jwt?/1` + helpers privados
- `lib/thalamus_web/plugs/authenticate_token.ex` — delega en `JwtSigner`, elimina duplicación
- `lib/thalamus_web/controllers/oauth2/userinfo_controller.ex` — fallback JWKS en `resolve_user_id/1`
- `test/thalamus_web/controllers/oauth2/userinfo_controller_test.exs` — tests nuevos

## Errores encontrados

- Credo: `cond` con una sola condición en `validate_claims` → reemplazado por `if`.
- Credo: nesting en `resolve_stateless_jwt_user_id` → refactorizado con `with`.
- Credo: alias desordenados + módulo anidado `Thalamus.Application.UseCases.ValidateToken` → alias ordenado + alias `ValidateToken`.

## Verificación

- `mix test` → 1916 tests, 0 failures (17 skipped pre-existentes).
- `test/thalamus_web/controllers/oauth2/userinfo_controller_test.exs` → 5 tests nuevos.

## Referencias

- [#154](https://github.com/ZeaCl/thalamus/issues/154)
- #69 documentó la misma causa raíz pero solo aplicó workaround en CI (usar PAT en vez del JWT de login).
- #6 agregó `domain_roles` al JWT (ya resuelto).
