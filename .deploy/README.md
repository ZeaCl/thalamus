# Thalamus - Deployment Guide

Complete deployment guide for deploying Thalamus OAuth2 Server to Digital Ocean.

## Overview

This deployment setup uses:
- **Docker + Docker Compose** for containerization
- **PostgreSQL 16** for database
- **Redis 7** for caching
- **Nginx** as reverse proxy
- **Let's Encrypt** for SSL/TLS certificates
- **Digital Ocean Droplet** as hosting platform

## Prerequisites

### Local Machine
- SSH access to your Digital Ocean droplet
- SSH key configured (typically `~/.ssh/id_ed25519`)
- Digital Ocean API token (for DNS automation)

### Digital Ocean
- A droplet running Ubuntu 22.04 LTS or later
- At least 2GB RAM, 1 vCPU, 50GB SSD
- Domain name configured in Digital Ocean DNS

## Quick Start

### 1. Generate Phoenix Secrets

Before deploying, generate secure secrets for production:

```bash
# From the Thalamus root directory
cd /Users/dev/Documents/zea/thalamus

# Generate 4 secrets (you'll need to run this 4 times)
mix phx.gen.secret
```

### 2. Configure Deployment

Edit `.deploy/config.sh` and update these values:

```bash
# REQUIRED: Update these values
SECRET_KEY_BASE="<output from mix phx.gen.secret>"
VERIFICATION_TOKEN_SECRET="<output from mix phx.gen.secret>"
PASSWORD_RESET_SECRET="<output from mix phx.gen.secret>"
SESSION_SECRET="<output from mix phx.gen.secret>"

# RECOMMENDED: Change default passwords
POSTGRES_PASSWORD="your-secure-password-here"
REDIS_PASSWORD="your-secure-redis-password-here"

# OPTIONAL: Configure SMTP for email (if not using default)
SMTP_HOST="smtp.sendgrid.net"
SMTP_PORT="587"
SMTP_USER="your-smtp-user"
SMTP_PASSWORD="your-smtp-password"
```

**Available Configuration Options:**

| Variable | Description | Default |
|----------|-------------|---------|
| `VPS_IP` | IP address of your droplet | `104.236.120.97` |
| `VPS_USER` | SSH user for droplet | `root` |
| `DOMAIN` | Domain for Thalamus | `auth.zea.cl` |
| `API_PORT` | Internal port for Phoenix | `4000` |
| `POSTGRES_DB` | Database name | `thalamus_prod` |
| `POSTGRES_USER` | Database user | `thalamus` |
| `EMAIL_FROM` | Sender email address | `noreply@zea.cl` |
| `CORS_ORIGINS` | Allowed CORS origins | Comma-separated list |

### 3. Deploy to Production

```bash
cd .deploy
./deploy.sh
```

The deployment script will:
1. Validate configuration
2. Check SSH connectivity
3. Install Docker and Nginx on VPS (if needed)
4. Compress and upload application files
5. Build Docker containers
6. Run database migrations
7. Configure Nginx reverse proxy
8. Start all services

**Deployment takes approximately 5-10 minutes** (mostly Docker build time).

### 4. Configure DNS

```bash
./setup-dns.sh
```

This script will:
- Verify your Digital Ocean API token
- Check if domain exists in DO
- Create an A record pointing your domain to the VPS IP
- DNS propagation takes 5-60 minutes

You can manually verify DNS propagation:
```bash
dig auth.zea.cl
nslookup auth.zea.cl
```

### 5. Configure SSL (HTTPS)

**Important:** Wait until DNS has propagated before running this step.

```bash
./setup-ssl.sh
```

This script will:
- Verify DNS is pointing to the correct IP
- Install Certbot
- Obtain Let's Encrypt SSL certificate
- Configure automatic renewal (every 60 days)
- Update Nginx to redirect HTTP → HTTPS

## Post-Deployment

### Verify Deployment

Check that all services are running:
```bash
./status.sh
```

This displays:
- Docker container status
- System resources (CPU, RAM, disk)
- Service health checks
- Network ports

### View Logs

```bash
./logs.sh
```

Options:
1. Thalamus App logs (Elixir/Phoenix)
2. PostgreSQL database logs
3. Redis cache logs
4. All containers
5. Nginx access log
6. Nginx error log

### Restart Services

```bash
./restart.sh
```

Options:
1. Restart Thalamus App only
2. Restart Database only
3. Restart Redis only
4. Restart all containers
5. Restart Nginx
6. Restart everything

## Accessing Thalamus

After deployment with SSL configured:

- **Health Check:** `https://auth.zea.cl/health`
- **Login Dashboard:** `https://auth.zea.cl/`
- **OAuth2 Authorization:** `https://auth.zea.cl/oauth/authorize`
- **Token Endpoint:** `https://auth.zea.cl/oauth/token`
- **User Info (OIDC):** `https://auth.zea.cl/oauth/userinfo`

## Management Commands

### SSH into VPS

```bash
ssh -i ~/.ssh/id_ed25519 root@104.236.120.97
```

### View Container Logs Directly

```bash
# SSH into VPS first
cd /opt/thalamus
docker compose logs -f thalamus
docker compose logs -f postgres
docker compose logs -f redis
```

### Database Access

```bash
# SSH into VPS first
docker exec -it thalamus_postgres psql -U thalamus -d thalamus_prod
```

### Redis Access

```bash
# SSH into VPS first
docker exec -it thalamus_redis redis-cli -a <REDIS_PASSWORD>
```

### Run Elixir Console

```bash
# SSH into VPS first
cd /opt/thalamus
docker compose exec thalamus bin/thalamus remote
```

## Troubleshooting

### Deployment Fails

**Check logs:**
```bash
./logs.sh  # Select option 1 for app logs
```

**Common issues:**
- **Secrets not configured:** Edit `config.sh` and set all `SECRET_*` variables
- **SSH connection fails:** Verify VPS IP and SSH key path
- **Docker build fails:** Check if VPS has enough disk space (50GB recommended)
- **Migration fails:** Database may not be ready, wait 30 seconds and redeploy

### DNS Not Propagating

**Check DNS status:**
```bash
dig auth.zea.cl @8.8.8.8
```

**If not resolving:**
- Wait 5-60 minutes for propagation
- Verify domain exists in Digital Ocean DNS panel
- Check that A record points to correct IP

### SSL Certificate Fails

**Common causes:**
- DNS not propagated yet (wait longer)
- Nginx not serving on port 80 (check `./status.sh`)
- Let's Encrypt rate limit hit (max 5 failed attempts per week)

**Solution:**
```bash
# Wait for DNS to propagate
dig auth.zea.cl

# Verify HTTP is working
curl http://auth.zea.cl/health

# Try SSL setup again
./setup-ssl.sh
```

### Container Won't Start

**Check container status:**
```bash
./status.sh
```

**View specific container logs:**
```bash
ssh root@<VPS_IP>
cd /opt/thalamus
docker compose logs thalamus --tail=100
```

**Restart container:**
```bash
./restart.sh  # Select option 1 for Thalamus app
```

### Database Connection Issues

**Check database health:**
```bash
./status.sh  # Look for "Database: conectada"
```

**Verify database credentials in .env:**
```bash
ssh root@<VPS_IP>
cat /opt/thalamus/.env | grep POSTGRES
```

**Restart database:**
```bash
./restart.sh  # Select option 2 for database
```

## Updating Thalamus

To update to a new version:

```bash
# 1. Pull latest code locally
cd /Users/dev/Documents/zea/thalamus
git pull origin main

# 2. Redeploy
cd .deploy
./deploy.sh
```

The deploy script will:
- Stop old containers
- Build new Docker image with latest code
- Run any new migrations
- Start updated containers

**Note:** There will be ~30 seconds of downtime during the update.

## Backup and Recovery

### Database Backup

```bash
# SSH into VPS
ssh root@<VPS_IP>

# Create backup
docker exec thalamus_postgres pg_dump -U thalamus thalamus_prod > backup_$(date +%Y%m%d).sql

# Download backup to local machine
scp root@<VPS_IP>:~/backup_*.sql ./backups/
```

### Database Restore

```bash
# Upload backup to VPS
scp ./backups/backup_20260116.sql root@<VPS_IP>:~/

# SSH into VPS
ssh root@<VPS_IP>

# Restore database
docker exec -i thalamus_postgres psql -U thalamus thalamus_prod < backup_20260116.sql
```

## Security Considerations

### Secrets Management
- All secrets stored in `.env` file on VPS (not in git)
- `config.sh` contains placeholders (must be updated before deploy)
- Never commit actual secrets to git

### Firewall Configuration
```bash
# SSH into VPS
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (for Let's Encrypt)
ufw allow 443/tcp   # HTTPS
ufw enable
```

### Regular Updates
```bash
# SSH into VPS
apt update && apt upgrade -y
```

## Architecture

```
Internet
    ↓
Nginx (Port 80/443)
    ↓
Thalamus App (Phoenix on Port 4000)
    ↓
PostgreSQL (Port 5432) + Redis (Port 6379)
```

All components run in Docker containers on the same VPS within the `thalamus_network` bridge network.

## Support

For issues or questions:
- GitHub Issues: https://github.com/chinostroza/thalamus/issues
- Email: noreply@zea.cl

## License

MIT License - see main repository for details.
