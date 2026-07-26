# Fix: OrganizationId UUID validation

- **Issue**: #117
- **Rama**: hotfix/117-org-id-validation
- **PR**: #118
- **Estado**: ✅ merged

## Qué se hizo
- Agregada validación UUID en `OrganizationId.validate_format/1` para rechazar valores no-UUID
- Actualizados doctests con UUIDs válidos
- El controller ahora responde 400 en vez de 500 cuando el org_id no es UUID

## Decisiones clave
- Regex UUID: `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`
- La validación se hace sobre el valor sin prefijo `org_`
- El error ya era capturado por el `with/else` del controller (atom → 400 Bad Request)

## Archivos modificados
- `lib/thalamus/domain/value_objects/organization_id.ex`

## Errores encontrados
- `Ecto.ChangeError: value "org1" for organization_id does not match type :binary_id` → el VO no validaba UUID, Ecto fallaba al dumpear
- `"org1"` pasaba `String.length >= 3` y `~r/^[a-zA-Z0-9_-]+$/` sin problema

## Referencias
- [#117](https://github.com/ZeaCl/thalamus/issues/117)
- [#118](https://github.com/ZeaCl/thalamus/pull/118)
