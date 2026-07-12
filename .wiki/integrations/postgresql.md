# PostgreSQL

- **Host local**: `localhost:5432`
- **Host Docker**: `postgres:5432` (internal network)
- **Database dev**: `thalamus_dev`
- **Database test**: `thalamus_test`
- **User**: `postgres`
- **Password Docker**: `postgres` (definido en `docker-compose.yml`)

## Conexión

```bash
# Local
psql -U postgres -d thalamus_dev

# Docker
docker-compose exec postgres psql -U postgres -d thalamus_dev
```

## ORM

- **Ecto**: `ecto_sql` + `postgrex`
- Repo: `Thalamus.Repo`
- Schemas en `lib/thalamus/infrastructure/persistence/schemas/`
- Migraciones en `priv/repo/migrations/`

## Schemas principales

| Schema | Tabla | Descripción |
|---|---|---|
| public | users | Usuarios con email, password_hash, mfa_enabled |
| public | organizations | Multi-tenant: nombre, slug, plan |
| public | oauth2_clients | Aplicaciones registradas (client_id, client_secret, redirect_uris) |
| public | oauth2_tokens | Access tokens, refresh tokens (hasheados) |
| public | oauth2_authorization_codes | Authorization codes (hasheados, single-use) |
| public | user_organization_roles | Roles de usuario por organización (RBAC) |
| public | mfa_sessions | Sesiones MFA activas por usuario |
| public | audit_logs | Registro de eventos de seguridad |

## Convenciones Ecto

- Timestamps: `utc_datetime` (configurado en `config.exs`)
- IDs: UUID v4 (`binary_id` en migrations)
- Campos `TEXT` en PostgreSQL → type `:string` en Ecto
- `Ecto.Changeset.get_field/2` para leer campos del changeset
- Campos programáticos (ej. `user_id`) NO van en `cast/3`
- Preload de asociaciones antes de acceder en templates

## Salud

```bash
mix ecto.migrations     # Ver migraciones pendientes
mix ecto.create         # Crear DB si no existe
```
