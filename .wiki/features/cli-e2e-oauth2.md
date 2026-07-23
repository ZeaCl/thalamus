# CLI E2E — OAuth2 ROPC flow

- **Issue**: #39, #64, #69
- **Estado**: ✅ merged

## Qué se hizo
- Implementado flujo OAuth2 `password` grant (ROPC) para tests E2E autenticados
- Agregado `"password"` a `allowed_grant_types` del client `internal_login` en seeds
- Creado script `scripts/test-cli.sh` con 12 tests (7 públicos + 5 autenticados)

## Decisiones clave
- Usar OAuth2 password grant en vez de login JWT para auth en E2E
- El JWT de `/api/public/login` no es token OAuth2 → no persiste en tabla `tokens` → `/oauth/userinfo` y `AuthenticateToken` lo rechazan
- `internal_login` client ya existía en seeds con `client_credentials`, solo faltaba `password`
- Script ejecutable localmente: `./scripts/test-cli.sh`

## Archivos modificados
- `priv/repo/seeds.exs` — agregado `"password"` grant
- `scripts/test-cli.sh` — nuevo script de tests
- `.github/workflows/cli-e2e.yml` — refactorizado (npm link, build, sin cache)
- `lib/thalamus/domain/services/personal_access_token_generator.ex` — fix Mix.env()
- `lib/thalamus/application/use_cases/generate_tokens.ex` — organization_id en token_data
- `lib/thalamus_web/controllers/api/personal_access_token_controller.ex` — fallback org_id

## Errores encontrados
- `Mix.env()` no disponible en release Docker → `UndefinedFunctionError` en PAT generator → 500
- `npm link` sin `npm install` → `commander` no encontrado
- `cache-from: type=gha` en CLI E2E → capas Docker cacheadas con código viejo → 401 falsos
- `login` sobreescribía `config.json` con JWT de sesión → tests posteriores usaban token inválido

## Referencias
- PR #39
- Issues #64, #69, #70, #71, #72, #73
