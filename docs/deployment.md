# Deployment

Thalamus can be deployed standalone or as part of the ZEA Platform.

---

## Requirements

| Component | Minimum | Recommended |
|---|---|---|
| **OS** | Linux (Ubuntu 20.04+) | Ubuntu 22.04+ |
| **Elixir** | 1.19+ | 1.19+ |
| **Erlang/OTP** | 27+ | 27+ |
| **PostgreSQL** | 12+ | 16+ |
| **Redis** | Optional | 7+ |
| **RAM** | 2 GB | 4 GB+ |
| **CPU** | 2 cores | 4+ cores |
| **Storage** | 10 GB SSD | 20 GB+ SSD |

---

## Quick Start (Local)

```bash
git clone <thalamus-repo>
cd thalamus
mix deps.get
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
mix phx.server
```

Thalamus: `http://localhost:4000`  
Mailbox: `http://localhost:4000/dev/mailbox`

---

## Docker

### Standalone

```bash
# Build
docker build -t thalamus .

# Run
docker run -d \
  -e DATABASE_URL=ecto://user:pass@host:5432/thalamus_prod \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  -e PHX_HOST=your-domain.com \
  -p 4000:4000 \
  thalamus
```

### Docker Compose

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: thalamus
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: thalamus_prod
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U thalamus"]
      interval: 5s

  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redisdata:/data

  thalamus:
    image: ghcr.io/zeacl/thalamus:latest
    environment:
      DATABASE_URL: ecto://thalamus:${DB_PASSWORD}@postgres:5432/thalamus_prod
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/0
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      PHX_HOST: ${PHX_HOST}
      PORT: 4000
    ports:
      - "4000:4000"
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  pgdata:
  redisdata:
```

```bash
# Start
docker compose up -d

# Run migrations
docker compose exec thalamus bin/thalamus eval "Thalamus.Release.migrate()"

# Logs
docker compose logs -f thalamus
```

---

## Production

### 1. Generate Secrets

```bash
mix phx.gen.secret 64
```

### 2. Environment Variables

```bash
# .env.production
MIX_ENV=prod
PHX_HOST=auth.zea.cl
PORT=4000
SECRET_KEY_BASE=<generated-secret>
DATABASE_URL=ecto://thalamus_user:<password>@localhost:5432/thalamus_prod
REDIS_URL=redis://:<password>@localhost:6379/0
FROM_EMAIL=noreply@your-domain.com
FROM_NAME="Thalamus"
SMTP_RELAY=smtp.sendgrid.net
SMTP_USERNAME=apikey
SMTP_PASSWORD=<sendgrid-api-key>
SMTP_PORT=587
POOL_SIZE=20
CORS_ORIGINS=https://app.your-domain.com
```

```bash
chmod 600 .env.production
```

### 3. Release

```bash
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix release
_build/prod/rel/thalamus/bin/thalamus start
```

### 4. Database

```sql
CREATE USER thalamus_user WITH PASSWORD '<strong-password>';
CREATE DATABASE thalamus_prod;
GRANT ALL PRIVILEGES ON DATABASE thalamus_prod TO thalamus_user;
ALTER DATABASE thalamus_prod OWNER TO thalamus_user;
```

```bash
_build/prod/rel/thalamus/bin/thalamus eval "Thalamus.Release.migrate()"
```

---

## Reverse Proxy (Nginx)

```nginx
server {
    listen 443 ssl http2;
    server_name auth.zea.cl;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=oauth:10m rate=10r/s;

    location /oauth/ {
        limit_req zone=oauth burst=5 nodelay;
        proxy_pass http://localhost:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://localhost:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

---

## ZEA Platform (Multi-Service)

Thalamus runs as the auth service alongside Cerebelum, Cranium, and Caddy:

```yaml
# docker-compose.prod.yml
thalamus:
  image: ghcr.io/zeacl/thalamus:latest
  environment:
    DATABASE_URL: ecto://thalamus_user:${DB_PASSWORD}@postgres:5432/thalamus_prod
    MIX_ENV: prod
    PHX_HOST: auth.zea.cl
    PORT: 4000
    SECRET_KEY_BASE: ${SECRET_KEY_BASE}
  depends_on:
    postgres:
      condition: service_healthy

caddy:
  image: caddy:2-alpine
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./Caddyfile:/etc/caddy/Caddyfile
```

```caddyfile
auth.zea.cl {
    reverse_proxy thalamus:4000
}
```

---

## Health Check

```bash
curl http://localhost:4000/api/public/health
# {"status":"ok","checks":{"database":"ok","cache":"ok"}}
```

---

## See Also

- [Configuration](configuration.md) — Email, plans, scopes, feature flags
- [Architecture Overview](../architecture/overview.md) — System design
