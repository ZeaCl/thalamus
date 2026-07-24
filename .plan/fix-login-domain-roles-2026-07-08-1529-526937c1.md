# Plan: Fix Login JWT — Incluir `domain_roles`

- **Repo**: `zea/thalamus`
- **Plan ID**: `fix-login-domain-roles-2026-07-08-1529-526937c1`
- **Issue**: [ZeaCl/thalamus#6](https://github.com/ZeaCl/thalamus/issues/6) — `[BUG] JWT de /api/public/login no incluye domain_roles`
- **Fecha**: 2026-07-08 15:29 UTC
- **Ticket**: `.soport/ticket-526937c1-001.md`

---

## 1. Problema

`POST /api/public/login` genera un JWT sin el claim `domain_roles`. Esto impide que servicios downstream como `fm_funds` validen correctamente las requests — su `ClaimsValidationPlug` exige `domain_roles` no vacío y devuelve `403 missing_domain_roles`.

### Evidencia

**JWT actual de login (decodificado):**
```json
{
  "email": "c@zea.cl",
  "exp": 1783526974,
  "iat": 1783523374,
  "name": "Carlos Hinostroza",
  "organization_id": "org_ea7b11ea-852c-44e5-aee1-a761ec76eaea",
  "sub": "c0000000-852c-44e5-aee1-a761ec76eaea"
}
```

**JWT esperado (como lo genera el flujo OAuth2 vía JwtSigner):**
```json
{
  "sub": "user_c0000000-...",
  "email": "c@zea.cl",
  "domain_roles": [
    {
      "domain": "funds",
      "role": "gp_admin",
      "scopes": ["read", "write"],
      "org_id": "org_ea7b11ea-..."
    }
  ],
  "scopes": ["read", "write"]
}
```

---

## 2. Causa Raíz

`LoginController` tiene su propia función `generate_token/1` que construye claims JWT manualmente, **sin consultar `user_domain_roles` ni incluir `domain_roles`**.

Mientras tanto, `JwtSigner.sign_access_token/1` (usado por el flujo OAuth2 vía `GenerateTokens`) **sí** incluye `domain_roles` mediante `add_domain_roles/1`, que consulta la tabla `user_domain_roles`.

### Dos caminos de generación de JWT

| Aspecto | `LoginController.generate_token/1` (roto) | `JwtSigner.sign_access_token/1` (correcto) |
|---|---|---|
| Algoritmo | HS256 (simétrico) | RS256 (asimétrico) |
| `domain_roles` | ❌ No incluido | ✅ Incluido |
| `scopes` | ❌ No incluido | ✅ Incluido |
| Formato `sub` | UUID raw | `user_<uuid>` |
| Usado por | `POST /api/public/login` | `POST /oauth/token` |
| Arquitectura | Controller → Repo directo → JWT manual | Controller → UseCase → JwtSigner |

### Violaciones arquitectónicas del LoginController actual

1. **Bypasea Clean Architecture**: accede a `Repo` directamente, sin ports
2. **Duplica lógica de auth**: misma lógica que `SessionController` y `AuthenticateUser`
3. **Duplica lógica de firma JWT**: misma lógica que `JwtSigner`
4. **Algoritmo inconsistente**: HS256 vs RS256 del estándar

---

## 3. Solución

Refactorizar `LoginController` para que use los componentes estándar del proyecto:

```
LoginController  →  AuthenticateUser (use case)  →  JwtSigner.sign_access_token/1
                         ↑                                    ↑
                   Auth + MFA + auditoría          RS256 + domain_roles + scopes
```

### Qué se ELIMINA

- `LoginController.authenticate/2` — reemplazado por `AuthenticateUser.execute/2`
- `LoginController.generate_token/1` — reemplazado por `JwtSigner.sign_access_token/1`
- `LoginController.signing_secret/0` — ya no necesario (RS256 usa archivo de clave privada)
- `alias Thalamus.Repo` en el controller
- `alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema` en el controller

### Qué se AGREGA

- `@deps` con `user_repository`, `audit_logger` inyectados
- Llamada a `AuthenticateUser.execute(request, deps)`
- Llamada a `JwtSigner.sign_access_token(claims_map)`
- Construcción de `AuthenticationRequest` DTO
- Mapeo de `AuthenticationResponse` a claims para `JwtSigner`

### Cambio de algoritmo de firma

| Antes | Después |
|---|---|
| HS256 con `secret_key_base` | RS256 con clave privada (`priv/jwt_private_key.pem`) |
| Mismo secreto para firmar y validar | Firma asimétrica, validación vía JWKS |

**Impacto en consumers**: `fm_funds` y otros servicios ya validan contra `/.well-known/jwks.json` (clave pública RS256). No debería haber breaking change si ya usan JWKS. Si algún consumer tiene hardcodeado el secreto HS256, necesitará actualizarse.

---

## 4. Archivos afectados

| Archivo | Cambio |
|---|---|
| `lib/thalamus_web/controllers/api/login_controller.ex` | Refactor completo del `create/2` y eliminación de funciones privadas `authenticate/2`, `generate_token/1`, `signing_secret/0` |
| `test/thalamus_web/controllers/api/login_controller_test.exs` | Actualizar tests para mockear `AuthenticateUser` y `JwtSigner`, verificar `domain_roles` en JWT |

### Archivos que NO se tocan (pero se usan)

| Archivo | Rol |
|---|---|
| `lib/thalamus/application/use_cases/authenticate_user.ex` | Use case existente — ya maneja auth + MFA + auditoría |
| `lib/thalamus/infrastructure/jwt_signer.ex` | Signer existente — ya incluye `domain_roles` |
| `lib/thalamus/application/dtos/authentication_request.ex` | DTO para el request de auth |
| `lib/thalamus/application/dtos/authentication_response.ex` | DTO para la respuesta de auth |
| `lib/thalamus/application/ports/user_repository.ex` | Port para UserRepository |
| `lib/thalamus/infrastructure/repositories/postgresql_user_repository.ex` | Implementación concreta |

---

## 5. Riesgos y mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Cambio de HS256 → RS256 rompe validadores que usan secreto compartido | Baja | Alto | Verificar que `fm_funds` y cerebelum validan vía JWKS. Si no, coordinar migración |
| Formato `sub` cambia de UUID raw a `user_<uuid>` | Media | Medio | Verificar qué esperan los consumers |
| `AuthenticateUser` tiene lógica de MFA que podría cambiar el flujo del login API | Baja | Medio | El login actual no soporta MFA; `AuthenticateUser` devuelve `mfa_required` si el user tiene MFA — manejar ese caso |
| `JwtSigner` tiene dependencia en archivos de clave en `priv/` | Baja | Bajo | Ya existen en el proyecto, usados por OAuth2 |

---

## 6. Validación post-implementación

- [ ] `POST /api/public/login` devuelve JWT con `domain_roles` poblado
- [ ] `fm_funds` acepta el JWT sin `403 missing_domain_roles`
- [ ] Tests existentes pasan
- [ ] Nuevos tests cubren `domain_roles` en el JWT
- [ ] El flujo OAuth2 (`POST /oauth/token`) no se rompe
- [ ] `mix test` verde
- [ ] `mix credo --strict` limpio

---

## 7. Referencias

- Issue original: [ZeaCl/thalamus#6](https://github.com/orgs/ZeaCl/projects/11?pane=issue&itemId=210359848&issue=ZeaCl%7Cthalamus%7C6)
- `fm_funds` QA Epic: ZeaCl/fm_funds#106
- `ClaimsValidationPlug` en fm_funds: exige `domain_roles` no vacío
- Tabla `user_domain_roles`: migración `20260524000002_create_domain_scopes.exs`
- Arquitectura de referencia: `TokenController` → `GenerateTokens` → `JwtSigner`
