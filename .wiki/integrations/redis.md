# Redis

- **Host local**: `localhost:6379`
- **Host Docker**: `redis:6379` (internal network)
- **Password Docker**: `redis_password` (definido en `docker-compose.yml`)
- **Database**: `0`
- **URL**: `redis://localhost:6379/0` (configurable vía `REDIS_URL`)

## Usos en Thalamus

### 1. Caché (Cachex + Redix)
- Cachex para caché en memoria (rápido, local)
- Redix para caché compartido entre instancias (producción)
- Config: `redis_adapter: :redix`

### 2. Rate Limiting (Hammer)
- Hammer usa ETS por defecto
- Redis puede usarse como backend distribuido para multi-nodo

## Conexión

```bash
# Docker
docker-compose exec redis redis-cli -a redis_password

# Monitoreo
docker-compose exec redis redis-cli -a redis_password MONITOR

# Keys
docker-compose exec redis redis-cli -a redis_password KEYS "*"
```

## Configuración

```elixir
# config/config.exs
config :thalamus,
  redis_url: System.get_env("REDIS_URL", "redis://localhost:6379/0"),
  redis_adapter: :redix
```
