# Tasks: Fix Login JWT — Incluir `domain_roles`

- **Repo**: `zea/thalamus`
- **Plan**: `fix-login-domain-roles-2026-07-08-1529-526937c1`
- **Issue**: [ZeaCl/thalamus#6](https://github.com/orgs/ZeaCl/projects/11?pane=issue&itemId=210359848&issue=ZeaCl%7Cthalamus%7C6)
- **Ticket**: `.soport/ticket-526937c1-001.md`

---

## Fase 1: Investigación ✅

- [x] Leer `LoginController` — confirmar que `generate_token/1` no incluye `domain_roles`
- [x] Leer `JwtSigner` — confirmar que `sign_access_token/1` sí incluye `domain_roles` vía `add_domain_roles/1`
- [x] Leer `AuthenticateUser` — use case existente para auth
- [x] Leer `TokenController` — patrón estándar de arquitectura
- [x] Leer `GenerateTokens` — flujo OAuth2 que usa `JwtSigner`
- [x] Leer `user_domain_role_schema.ex` — estructura de la tabla
- [x] Leer migración `20260524000002_create_domain_scopes.exs` — schema DB
- [x] Leer `RequireScope` plug — cómo Thalamus autoriza sus propios endpoints
- [x] Leer `ValidateToken` — cómo se validan tokens
- [x] Leer `docs/api/authentication.md` — contrato documentado del endpoint
- [x] Leer `docs/api/domains.md` — concepto de dominios
- [x] Verificar tests existentes (`login_controller_test.exs`)

---

## Fase 2: Lectura de DTOs y ports necesarios ✅

- [x] Leer `lib/thalamus/application/dtos/authentication_request.ex`
- [x] Leer `lib/thalamus/application/dtos/authentication_response.ex`
- [x] Leer `lib/thalamus/application/ports/user_repository.ex`
- [x] Leer `lib/thalamus/application/ports/audit_logger.ex`
- [x] Leer `lib/thalamus/domain/entities/user.ex`
- [x] Leer `lib/thalamus/domain/value_objects/user_id.ex`
- [x] Leer `lib/thalamus/dependency_builder.ex`
- [x] Leer `lib/thalamus/infrastructure/repositories/postgresql_user_repository.ex`

---

## Fase 3: Implementación ✅

- [x] Refactorizar `LoginController.create/2`:
  - [x] Usar `DependencyBuilder.build_for_web(conn)` para inyección de dependencias
  - [x] Construir `AuthenticationRequest` DTO desde params
  - [x] Llamar `AuthenticateUser.execute(request, deps)`
  - [x] Manejar respuesta `{:ok, %{authenticated: true}}` → éxito
  - [x] Manejar `{:ok, %{mfa_required: true}}` → devolver respuesta MFA
  - [x] Manejar `{:error, reason}` → mapear a códigos HTTP con `error_code/1` + `error_description/1`
  - [x] Reemplazar `generate_token/1` por `JwtSigner.sign_access_token/1`
  - [x] Re-fetch user via `deps.user_repository.find_by_id` para claims completos
  - [x] Eliminar `authenticate/2`
  - [x] Eliminar `generate_token/1`
  - [x] Eliminar `signing_secret/0`
  - [x] Eliminar `alias Thalamus.Repo`
  - [x] Eliminar `alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema`
- [x] Agregar `alias` para nuevos módulos:
  - [x] `Thalamus.Application.UseCases.AuthenticateUser`
  - [x] `Thalamus.Application.DTOs.AuthenticationRequest`
  - [x] `Thalamus.DependencyBuilder`
  - [x] `Thalamus.Domain.ValueObjects.{UserId, Email}`
  - [x] `Thalamus.Infrastructure.JwtSigner`

---

## Fase 4: Tests ✅

- [x] Actualizar `test/thalamus_web/controllers/api/login_controller_test.exs`:
  - [x] Test: login exitoso con domain_roles → JWT incluye `domain_roles` claim
  - [x] Test: login exitoso sin domain_roles → JWT sin `domain_roles` key
  - [x] Test: credenciales inválidas → 401 `invalid_credentials`
  - [x] Test: usuario inexistente → 401 `invalid_credentials`
  - [x] Test: usuario suspendido → 401 `account_suspended`
  - [x] Test: usuario desactivado → 401 `account_suspended`
  - [x] Test: parámetros faltantes (email, password, body vacío) → 400
  - [x] Test: email case-insensitive
  - [x] Helper: `create_domain_role/4` para sembrar `user_domain_roles`

---

## Fase 5: Verificación

- [ ] `mix test` — todos los tests pasan
- [ ] `mix credo --strict` — sin warnings
- [ ] `mix format --check-formatted` — código formateado
- [ ] Verificar manualmente con curl que el JWT incluye `domain_roles`
- [ ] Verificar que `fm_funds` acepta el JWT (si hay ambiente disponible)

---

## Notas

- El cambio de HS256 → RS256 es intencional: alinea el login API con el estándar OAuth2
- Si `fm_funds` valida contra JWKS (`/.well-known/jwks.json`), no debería haber breaking change
- Si hay consumers hardcodeados con el secreto HS256, necesitarán migrar a validación JWKS
