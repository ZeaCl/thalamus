# ZEA Thalamus - Deployment Guide

This guide provides comprehensive instructions for deploying ZEA Thalamus to production environments.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Configuration](#environment-configuration)
3. [Docker Deployment](#docker-deployment)
4. [Manual Deployment](#manual-deployment)
5. [Cloud Platforms](#cloud-platforms)
6. [SSL/TLS Configuration](#ssltls-configuration)
7. [Database Setup](#database-setup)
8. [Monitoring & Logging](#monitoring--logging)
9. [Backup & Recovery](#backup--recovery)
10. [Security Checklist](#security-checklist)
11. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required
- **Operating System:** Linux (Ubuntu 20.04+, Debian 11+, or similar)
- **Elixir:** 1.17+ and Erlang 26+
- **PostgreSQL:** 16+
- **Redis:** 7+ (optional but recommended)
- **SSL Certificate:** For HTTPS (Let's Encrypt recommended)
- **Domain Name:** Configured with DNS pointing to your server

### Recommended
- **RAM:** Minimum 2GB, 4GB+ recommended
- **CPU:** 2+ cores
- **Storage:** 20GB+ SSD
- **Firewall:** UFW or iptables configured
- **Reverse Proxy:** Nginx or Caddy

---

## Environment Configuration

### 1. Generate Secrets

```bash
# Generate random secrets (64+ characters each)
mix phx.gen.secret 64

# Or use OpenSSL
openssl rand -base64 64
```

### 2. Create Production Config

Create `.env.production`:

```bash
# ============================================================================
# ZEA Thalamus - Production Configuration
# ============================================================================

# Application
MIX_ENV=prod
PHX_SERVER=true
PHX_HOST=your-domain.com
PHX_PORT=4000

# Secrets (CHANGE THESE!)
SECRET_KEY_BASE=your-secret-key-base-min-64-chars-CHANGE-THIS
VERIFICATION_TOKEN_SECRET=your-verification-token-secret-CHANGE-THIS
PASSWORD_RESET_SECRET=your-password-reset-secret-CHANGE-THIS
SESSION_SECRET=your-session-secret-CHANGE-THIS

# Database
DATABASE_URL=ecto://thalamus_user:STRONG_PASSWORD@localhost:5432/thalamus_prod
DB_HOST=localhost
DB_PORT=5432
DB_NAME=thalamus_prod
DB_USER=thalamus_user
DB_PASSWORD=STRONG_DATABASE_PASSWORD_CHANGE_THIS
DB_POOL_SIZE=20

# Redis
REDIS_URL=redis://:STRONG_REDIS_PASSWORD@localhost:6379/0
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=STRONG_REDIS_PASSWORD_CHANGE_THIS

# Email (SMTP)
EMAIL_MODE=production
EMAIL_FROM=noreply@your-domain.com
EMAIL_FROM_NAME="ZEA Thalamus"
EMAIL_BASE_URL=https://your-domain.com

# SMTP Configuration (example: SendGrid, Mailgun, AWS SES)
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=YOUR_SMTP_API_KEY

# CORS
CORS_ORIGINS=https://app.your-domain.com,https://your-domain.com

# Security
ENABLE_SSL=true
FORCE_SSL=true

# Logging
LOG_LEVEL=info
```

### 3. Protect Secrets

```bash
# Set correct permissions
chmod 600 .env.production

# Never commit to git
echo ".env.production" >> .gitignore
```

---

## Docker Deployment

### Quick Start (Recommended)

```bash
# 1. Clone repository
git clone <repository_url>
cd thalamus

# 2. Copy and configure environment
cp .env.production.example .env.production
# Edit .env.production with your values

# 3. Start services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 4. Run migrations
docker-compose exec thalamus bin/thalamus eval "Thalamus.Release.migrate()"

# 5. Check logs
docker-compose logs -f thalamus
```

### With Custom Nginx

Create `nginx/nginx.conf`:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream thalamus {
        server thalamus:4000;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;
    limit_req_zone $binary_remote_addr zone=oauth:10m rate=10r/s;

    server {
        listen 80;
        server_name your-domain.com;

        # Redirect to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # Security Headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "DENY" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Logging
        access_log /var/log/nginx/thalamus_access.log;
        error_log /var/log/nginx/thalamus_error.log;

        # OAuth2 endpoints (stricter rate limiting)
        location /oauth/ {
            limit_req zone=oauth burst=5 nodelay;
            proxy_pass http://thalamus;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # API endpoints
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://thalamus;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Health check (no rate limiting)
        location /api/public/health {
            proxy_pass http://thalamus;
            access_log off;
        }

        # Default location
        location / {
            proxy_pass http://thalamus;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

---

## Manual Deployment

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y build-essential git curl postgresql-16 redis-server nginx certbot python3-certbot-nginx

# Install Erlang
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt update
sudo apt install -y esl-erlang=1:26.2.1-1

# Install Elixir
sudo apt install -y elixir=1.17.0-1
```

### 2. Setup PostgreSQL

```bash
# Create database user
sudo -u postgres createuser -P thalamus_user

# Create database
sudo -u postgres createdb -O thalamus_user thalamus_prod

# Enable extensions
sudo -u postgres psql -d thalamus_prod -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
sudo -u postgres psql -d thalamus_prod -c "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";"
```

### 3. Setup Redis

```bash
# Configure Redis
sudo nano /etc/redis/redis.conf

# Set:
# requirepass YOUR_REDIS_PASSWORD
# maxmemory 256mb
# maxmemory-policy allkeys-lru

# Restart Redis
sudo systemctl restart redis
```

### 4. Deploy Application

```bash
# Create deploy user
sudo useradd -m -s /bin/bash thalamus
sudo su - thalamus

# Clone repository
git clone <repository_url> ~/thalamus
cd ~/thalamus

# Install dependencies
mix local.hex --force
mix local.rebar --force
mix deps.get --only prod

# Compile assets
MIX_ENV=prod mix assets.deploy

# Build release
MIX_ENV=prod mix release

# Run migrations
_build/prod/rel/thalamus/bin/thalamus eval "Thalamus.Release.migrate()"
```

### 5. Create Systemd Service

Create `/etc/systemd/system/thalamus.service`:

```ini
[Unit]
Description=ZEA Thalamus OAuth2 Server
After=network.target postgresql.service redis.service

[Service]
Type=exec
User=thalamus
Group=thalamus
WorkingDirectory=/home/thalamus/thalamus
Environment=LANG=en_US.UTF-8
Environment=MIX_ENV=prod
Environment=PHX_SERVER=true
EnvironmentFile=/home/thalamus/thalamus/.env.production

ExecStart=/home/thalamus/thalamus/_build/prod/rel/thalamus/bin/thalamus start
ExecStop=/home/thalamus/thalamus/_build/prod/rel/thalamus/bin/thalamus stop

Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=thalamus

[Install]
WantedBy=multi-user.target
```

Start service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable thalamus
sudo systemctl start thalamus
sudo systemctl status thalamus
```

---

## Cloud Platforms

### AWS (Elastic Beanstalk)

```bash
# Install EB CLI
pip install awsebcli

# Initialize
eb init

# Create environment
eb create thalamus-prod \
  --instance-type t3.medium \
  --envvars \
    SECRET_KEY_BASE=$SECRET_KEY_BASE,\
    DATABASE_URL=$DATABASE_URL,\
    REDIS_URL=$REDIS_URL

# Deploy
eb deploy
```

### Digital Ocean (App Platform)

Create `app.yaml`:

```yaml
name: zea-thalamus
services:
  - name: web
    build_command: mix deps.get && mix assets.deploy && mix release
    run_command: _build/prod/rel/thalamus/bin/thalamus start
    environment_slug: elixir
    instance_count: 2
    instance_size_slug: basic-s
    envs:
      - key: MIX_ENV
        value: prod
      - key: SECRET_KEY_BASE
        value: ${SECRET_KEY_BASE}
    health_check:
      http_path: /api/public/health

databases:
  - name: thalamus-db
    engine: PG
    version: "16"
  - name: thalamus-redis
    engine: REDIS
    version: "7"
```

### Google Cloud Run

```bash
# Build container
docker build -t gcr.io/YOUR_PROJECT/thalamus:latest .

# Push to GCR
docker push gcr.io/YOUR_PROJECT/thalamus:latest

# Deploy
gcloud run deploy thalamus \
  --image gcr.io/YOUR_PROJECT/thalamus:latest \
  --platform managed \
  --region us-central1 \
  --set-env-vars="SECRET_KEY_BASE=$SECRET_KEY_BASE" \
  --set-cloudsql-instances=YOUR_PROJECT:us-central1:thalamus-db
```

---

## SSL/TLS Configuration

### Let's Encrypt (Free)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Auto-renewal (cron)
sudo certbot renew --dry-run
```

### Custom Certificate

```bash
# Place certificates
sudo cp fullchain.pem /etc/ssl/certs/thalamus.crt
sudo cp privkey.pem /etc/ssl/private/thalamus.key
sudo chmod 600 /etc/ssl/private/thalamus.key
```

---

## Database Setup

### Initial Migration

```bash
# Using release
_build/prod/rel/thalamus/bin/thalamus eval "Thalamus.Release.migrate()"

# Or manually
MIX_ENV=prod mix ecto.migrate
```

### Seed Production Data

```bash
# Create admin user
MIX_ENV=prod mix run priv/repo/seeds.exs
```

---

## Monitoring & Logging

### Application Logs

```bash
# Systemd logs
sudo journalctl -u thalamus -f

# Docker logs
docker-compose logs -f thalamus

# Log rotation
sudo nano /etc/logrotate.d/thalamus
```

### Health Checks

```bash
# Check application health
curl https://your-domain.com/api/public/health

# Expected response
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2025-10-26T12:00:00Z",
  "checks": {
    "database": "ok",
    "cache": "ok"
  }
}
```

---

## Backup & Recovery

### Database Backups

```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump -U thalamus_user thalamus_prod | gzip > /backup/thalamus_$DATE.sql.gz

# Keep last 30 days
find /backup -name "thalamus_*.sql.gz" -mtime +30 -delete
```

### Automated Backups (cron)

```cron
# Daily at 2 AM
0 2 * * * /usr/local/bin/backup-thalamus.sh
```

### Restore

```bash
# Restore from backup
gunzip < backup.sql.gz | psql -U thalamus_user thalamus_prod
```

---

## Security Checklist

- [ ] All secrets changed from defaults
- [ ] SSL/TLS enabled and working
- [ ] Firewall configured (ports 80, 443 only)
- [ ] Database password is strong
- [ ] Redis password is strong
- [ ] SSH key-based authentication only
- [ ] Regular security updates enabled
- [ ] Backup system tested
- [ ] Monitoring and alerts configured
- [ ] Rate limiting verified
- [ ] CORS origins restricted
- [ ] Email sending tested
- [ ] Audit logs reviewed

---

## Troubleshooting

### Application Won't Start

```bash
# Check logs
sudo journalctl -u thalamus -n 100

# Check environment
cat .env.production

# Test database connection
psql -U thalamus_user -d thalamus_prod -h localhost
```

### Database Connection Failed

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check connection
psql -U thalamus_user -d thalamus_prod -h localhost

# Verify pg_hba.conf allows connections
sudo nano /etc/postgresql/16/main/pg_hba.conf
```

### Redis Connection Issues

```bash
# Check Redis is running
sudo systemctl status redis

# Test connection
redis-cli -a YOUR_REDIS_PASSWORD ping

# Check Redis config
sudo nano /etc/redis/redis.conf
```

### SSL Certificate Issues

```bash
# Test SSL
openssl s_client -connect your-domain.com:443

# Renew Let's Encrypt
sudo certbot renew

# Check Nginx config
sudo nginx -t
```

### High Memory Usage

```bash
# Check memory
free -h

# Check Erlang processes
_build/prod/rel/thalamus/bin/thalamus remote

# In console:
:observer.start()
```

---

## Performance Tuning

### PostgreSQL

```sql
-- /etc/postgresql/16/main/postgresql.conf
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
max_connections = 200
```

### Erlang VM

```bash
# In rel/env.sh.eex
export ERLANG_MAX_PORTS=16384
export ERL_MAX_ETS_TABLES=8192
```

---

## Support

For deployment issues:
1. Check logs first
2. Review this guide
3. Search existing issues
4. Open new issue with logs

---

**Last Updated:** October 26, 2025
**Version:** 1.0.0
