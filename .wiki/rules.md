# Reglas y Patrones

## Convenciones de código

### Clean Architecture
- Dependencias fluyen hacia adentro: Web → Application → Domain
- Capas internas NUNCA importan de capas externas
- Application define puertos (behaviours), Infrastructure los implementa
- Ver `docs/architecture/overview.md` para el diagrama completo

### Value Objects
- Validan en `new/1`: retorna `{:ok, vo}` o `{:error, reason}`
- Inmutables, implementan `String.Chars` y `Jason.Encoder`
- Usar `defstruct [:value]` con un solo campo

### Use Cases
- Una función `execute/2`: `execute(request, deps)`
- `deps` es un map con las implementaciones de puertos
- Usar `with` para el pipeline de operaciones
- Las dependencias se inyectan, no se hardcodean

### Repositories
- Implementan `@behaviour` del puerto correspondiente
- `to_domain/1` mapea Ecto schema → entidad de dominio
- `to_changeset/1` mapea entidad de dominio → Ecto changeset
- Métodos `find_by_*` retornan `{:ok, entity}` o `{:error, :not_found}`

### Seguridad
- Tokens: `:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)`
- Constant-time comparison: `Plug.Crypto.secure_compare/2`
- Passwords: `Bcrypt.hash_pwd_salt/2` con 10 rounds
- Rate limiting configurado en router pipelines

## Testing

### Capas y herramientas

| Capa | Mocks? | DB? | Helper |
|---|---|---|---|
| Domain | ❌ | ❌ | `use ExUnit.Case, async: true` |
| Application | ✅ Mox | ❌ | `use ExUnit.Case, async: true` |
| Infrastructure | ❌ | ✅ Sandbox | `use Thalamus.DataCase, async: true` |
| Controllers | ❌ | ✅ Sandbox | `use ThalamusWeb.ConnCase, async: true` |

### Comandos frecuentes
```bash
mix test                           # Todos los tests
mix test test/path/file.exs:42     # Una sola línea
mix test --failed                  # Solo fallidos
make test-domain                   # Solo domain
make test-controllers              # Solo controllers
make test-integration              # Solo integration
```

## Problemas conocidos

<!-- Agregar aquí bugs/problemas descubiertos que no están resueltos aún -->

## PostgreSQL

### Conexión local
```bash
# Directa
psql -U postgres -d thalamus_dev

# Docker
docker-compose exec postgres psql -U postgres -d thalamus_dev
```

### Migraciones
```bash
mix ecto.migrate        # Aplicar pendientes
mix ecto.rollback       # Revertir última
mix ecto.reset          # Drop + create + migrate + seed
mix ecto.migrations     # Ver estado
```

### Schemas
- `public` — usuarios, organizations, oauth2_clients, tokens
- Multi-tenant vía `organization_id` en cada tabla
- RLS no implementado aún (en roadmap)
