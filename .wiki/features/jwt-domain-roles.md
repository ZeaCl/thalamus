# JWT domain_roles — Fix + Documentación

- **Issue**: #6
- **Rama**: `fix/jwt-domain-roles`
- **Estado**: ✅ completado (#9 y #13 cerrados)
- **Sub-issues**: #9, #10, #11, #12, #13

## Qué se hizo

Investigación y fix del bug donde el JWT emitido por `POST /api/public/login` no incluye el claim `domain_roles`, rompiendo la autorización multi-tenant en servicios downstream como fm_funds.

## Root cause

`JwtSigner.fetch_domain_roles/1` (línea ~127 de `jwt_signer.ex`) tiene un `rescue _ -> []` que silencia **cualquier** error durante la query a `user_domain_roles`. Si la query falla por conexión, casteo de tipos Ecto, o cualquier excepción, retorna `[]` silenciosamente y el JWT sale sin los claims `domain_roles` ni `scopes`.

El flujo es:
1. `POST /api/public/login` → `LoginController.build_jwt/1`
2. → `JwtSigner.sign_access_token/1` con `user_id` (string con prefijo `user_`)
3. → `add_domain_roles/1`: extrae UUID del sub (`String.replace_prefix(sub, "user_", "")`)
4. → `fetch_domain_roles/1`: query a `user_domain_roles` donde `user_id == ^raw_uid`
5. → Si query falla: `rescue _ -> []` → JWT sin domain_roles

## Decisiones clave

- **No cambiar la estructura del JWT** — `domain_roles` es el claim canónico para autorización multi-tenant
- **Reducir el rescue scope**: solo capturar errores esperados (DB down), loguear el resto
- **Agregar Logger.warn** para detectar fallos en producción
- **Documentar el claim en `docs/`** para que integradores sepan cómo leer permisos

## Archivos modificados

- `lib/thalamus/infrastructure/jwt_signer.ex` — `fetch_domain_roles/1` fix
- `docs/api/authentication.md` — Sección JWT Claims
- `docs/api/domains.md` — Nota de relación con JWT
- `docs/architecture/overview.md` — UserDomainRole schema
- `.wiki/features/jwt-domain-roles.md` — Esta página

## Errores encontrados

- ✅ `rescue _ -> []` en fetch_domain_roles → Fix: validación `Ecto.UUID.cast` explícita + rescue específico (`DBConnection.ConnectionError`, `OwnershipError`) + `Logger.warning`

## Referencias

- Issue padre: [#6](https://github.com/ZeaCl/thalamus/issues/6)
- Sub-issues: [#9](https://github.com/ZeaCl/thalamus/issues/9), [#10](https://github.com/ZeaCl/thalamus/issues/10), [#11](https://github.com/ZeaCl/thalamus/issues/11), [#12](https://github.com/ZeaCl/thalamus/issues/12), [#13](https://github.com/ZeaCl/thalamus/issues/13)
- Impacto downstream: fm_funds `ClaimsValidationPlug` rechaza requests sin `domain_roles`
