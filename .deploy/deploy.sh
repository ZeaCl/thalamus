#!/bin/bash

# ============================================
# SCRIPT DE DEPLOYMENT PARA THALAMUS
# OAuth2 as a Service
# Con Docker + PostgreSQL + Redis + Nginx
# ============================================

# Cargar configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Variables locales
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMP_BUILD="/tmp/${PROJECT_NAME}_build_$(date +%s).tar.gz"

print_header "INICIANDO DEPLOYMENT DE THALAMUS -> ${DOMAIN}"
print_docker "Usando Docker + PostgreSQL + Redis + Elixir ${ELIXIR_VERSION}"

# ============================================
# PASO 0: VALIDAR CONFIGURACIÓN
# ============================================
print_header "PASO 0: Validando configuración"

if ! validate_config; then
    print_error "La configuración tiene errores. Por favor corrígelos antes de continuar."
    exit 1
fi

print_step "Configuración validada"

# ============================================
# PASO 1: VERIFICAR PREREQUISITOS LOCALES
# ============================================
print_header "PASO 1: Verificando prerequisitos locales"

# Verificar que estamos en el directorio correcto
if [ ! -f "${PROJECT_ROOT}/mix.exs" ]; then
    print_error "No se encontró mix.exs. Asegúrate de estar en el directorio correcto."
    exit 1
fi
print_step "Directorio del proyecto verificado"

# Verificar SSH key
if [ ! -f "${SSH_KEY_PATH}" ]; then
    print_error "No se encontró la SSH key en ${SSH_KEY_PATH}"
    exit 1
fi
print_step "SSH key encontrada"

# Verificar conexión SSH
print_info "Verificando conexión con el VPS..."
if ssh -i "${SSH_KEY_PATH}" -o ConnectTimeout=10 "${VPS_USER}@${VPS_IP}" "echo 'OK'" > /dev/null 2>&1; then
    print_step "Conexión SSH exitosa con ${VPS_IP}"
else
    print_error "No se pudo conectar al VPS. Verifica la IP y las credenciales."
    exit 1
fi

# ============================================
# PASO 2: INSTALAR DOCKER EN EL VPS
# ============================================
print_header "PASO 2: Verificando/instalando Docker en el VPS"

ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" << 'ENDSSH'
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}[i]${NC} Docker no encontrado. Instalando..."

    # Instalar Docker
    apt-get update -qq
    apt-get install -y ca-certificates curl gnupg lsb-release

    # Agregar Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Agregar repositorio
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Instalar Docker Engine
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Iniciar Docker
    systemctl enable docker
    systemctl start docker

    echo -e "${GREEN}[✓]${NC} Docker instalado"
else
    echo -e "${GREEN}[✓]${NC} Docker ya está instalado ($(docker --version))"
fi

# Verificar Docker Compose
if ! command -v docker compose &> /dev/null; then
    echo -e "${BLUE}[i]${NC} Docker Compose no encontrado"
    exit 1
else
    echo -e "${GREEN}[✓]${NC} Docker Compose disponible"
fi

# Verificar Nginx
if ! command -v nginx &> /dev/null; then
    echo -e "${BLUE}[i]${NC} Nginx no encontrado. Instalando..."
    apt-get update -qq
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo -e "${GREEN}[✓]${NC} Nginx instalado"
else
    echo -e "${GREEN}[✓]${NC} Nginx ya está instalado"
fi
ENDSSH

print_step "Docker y Nginx verificados/instalados"

# ============================================
# PASO 3: PREPARAR ARCHIVOS PARA DEPLOYMENT
# ============================================
print_header "PASO 3: Preparando archivos"

cd "${PROJECT_ROOT}" || exit 1

# Crear archivo comprimido con los archivos necesarios
print_info "Comprimiendo archivos de Thalamus..."
tar -czf "${TEMP_BUILD}" \
    --exclude='deps/' \
    --exclude='_build/' \
    --exclude='.git/' \
    --exclude='node_modules/' \
    --exclude='assets/node_modules/' \
    --exclude='*.db' \
    --exclude='.elixir_ls/' \
    mix.exs mix.lock \
    config/ \
    lib/ \
    priv/ \
    assets/ \
    .deploy/Dockerfile \
    .deploy/docker-compose.yml \
    2>/dev/null

if [ ! -f "${TEMP_BUILD}" ]; then
    print_error "Error al crear archivo comprimido"
    exit 1
fi

SIZE=$(du -h "${TEMP_BUILD}" | cut -f1)
print_step "Archivos comprimidos (${SIZE})"

# ============================================
# PASO 4: SUBIR ARCHIVOS AL VPS
# ============================================
print_header "PASO 4: Subiendo archivos al VPS"

print_info "Subiendo ${SIZE} al servidor..."
scp -i "${SSH_KEY_PATH}" "${TEMP_BUILD}" "${VPS_USER}@${VPS_IP}:/tmp/${PROJECT_NAME}.tar.gz" || {
    print_error "Error al subir archivos"
    rm -f "${TEMP_BUILD}"
    exit 1
}
print_step "Archivos subidos"

# Limpiar archivo temporal local
rm -f "${TEMP_BUILD}"

# ============================================
# PASO 5: CONFIGURAR APLICACIÓN EN EL VPS
# ============================================
print_header "PASO 5: Configurando aplicación en el VPS"

ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" << EOF
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "\${BLUE}[i]\${NC} Creando directorio de aplicación..."
mkdir -p ${REMOTE_DIR}

echo -e "\${BLUE}[i]\${NC} Extrayendo archivos..."
cd ${REMOTE_DIR}
tar -xzf /tmp/${PROJECT_NAME}.tar.gz
rm /tmp/${PROJECT_NAME}.tar.gz

# Mover archivos de .deploy al root
mv .deploy/Dockerfile .
mv .deploy/docker-compose.yml .

echo -e "\${BLUE}[i]\${NC} Creando archivo .env para Docker..."
cat > .env << 'ENVFILE'
# Database
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# Redis
REDIS_PASSWORD=${REDIS_PASSWORD}

# Application
DOMAIN=${DOMAIN}
API_PORT=${API_PORT}
SECRET_KEY_BASE=${SECRET_KEY_BASE}
VERIFICATION_TOKEN_SECRET=${VERIFICATION_TOKEN_SECRET}
PASSWORD_RESET_SECRET=${PASSWORD_RESET_SECRET}
SESSION_SECRET=${SESSION_SECRET}

# Email
EMAIL_FROM=${EMAIL_FROM}
EMAIL_FROM_NAME=${EMAIL_FROM_NAME}
EMAIL_BASE_URL=${EMAIL_BASE_URL}
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}
SMTP_USER=${SMTP_USER}
SMTP_PASSWORD=${SMTP_PASSWORD}

# CORS
CORS_ORIGINS=${CORS_ORIGINS}

# Logging
LOG_LEVEL=${LOG_LEVEL}
ENVFILE

echo -e "\${GREEN}[✓]\${NC} Archivos configurados"
EOF

print_step "Archivos extraídos y configurados"

# ============================================
# PASO 6: BUILD Y START DE DOCKER CONTAINERS
# ============================================
print_header "PASO 6: Iniciando contenedores Docker"

ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" << EOF
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

cd ${REMOTE_DIR}

echo -e "\${CYAN}[🐳]\${NC} Deteniendo contenedores anteriores..."
docker compose down 2>/dev/null || true

echo -e "\${CYAN}[🐳]\${NC} Building imagen Docker (esto puede tomar varios minutos)..."
docker compose build --no-cache

echo -e "\${CYAN}[🐳]\${NC} Iniciando contenedores..."
docker compose up -d

echo -e "\${CYAN}[🐳]\${NC} Esperando que los servicios estén listos..."
sleep 15

# Ejecutar migraciones
echo -e "\${CYAN}[🐳]\${NC} Ejecutando migraciones de base de datos..."
docker compose exec -T thalamus bin/thalamus eval "Thalamus.Release.migrate()"

# Verificar que los contenedores estén corriendo
if docker ps | grep -q thalamus_app && docker ps | grep -q thalamus_postgres && docker ps | grep -q thalamus_redis; then
    echo -e "\${GREEN}[✓]\${NC} Contenedores corriendo correctamente"
else
    echo -e "\${RED}[✗]\${NC} Error: Los contenedores no están corriendo"
    docker compose logs --tail=50
    exit 1
fi
EOF

print_docker "Contenedores Docker iniciados"

# ============================================
# PASO 7: CONFIGURAR NGINX
# ============================================
print_header "PASO 7: Configurando Nginx"

ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" << EOF
set -e

# Crear configuración de nginx
cat > /etc/nginx/sites-available/${PROJECT_NAME} << 'NGINX_CONF'
server {
    listen 80;
    server_name ${DOMAIN};

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logs
    access_log /var/log/nginx/thalamus-access.log;
    error_log /var/log/nginx/thalamus-error.log;

    # Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # OAuth2 / API
    location / {
        proxy_pass http://localhost:${API_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;

        # Timeouts for long-running requests
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINX_CONF

# Crear directorio para ACME challenge
mkdir -p /var/www/html/.well-known/acme-challenge

# Habilitar sitio
ln -sf /etc/nginx/sites-available/${PROJECT_NAME} /etc/nginx/sites-enabled/

# Deshabilitar sitio default si existe
rm -f /etc/nginx/sites-enabled/default

# Test de configuración
nginx -t

# Recargar nginx
systemctl reload nginx

echo "✓ Nginx configurado correctamente"
EOF

print_step "Nginx configurado para ${DOMAIN}"

# ============================================
# PASO 8: VERIFICAR DEPLOYMENT
# ============================================
print_header "PASO 8: Verificando deployment"

sleep 5

# Verificar que los contenedores estén corriendo
print_info "Verificando contenedores..."
ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" "cd ${REMOTE_DIR} && docker compose ps" && {
    print_step "Contenedores están activos"
} || {
    print_error "Error con los contenedores"
    print_info "Logs:"
    ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" "cd ${REMOTE_DIR} && docker compose logs --tail=50"
    exit 1
}

# ============================================
# DEPLOYMENT COMPLETADO
# ============================================
print_header "DEPLOYMENT COMPLETADO ✓"

echo ""
print_step "Thalamus OAuth2 está corriendo en el VPS con Docker"
echo ""
print_info "Acceso a Thalamus:"
echo -e "  ${GREEN}http://${VPS_IP}:${API_PORT}/health${NC}  (directo por IP)"
echo -e "  ${GREEN}http://${DOMAIN}/health${NC}  (por dominio - configurar DNS)"
echo ""
print_info "Dashboard:"
echo -e "  ${GREEN}http://${DOMAIN}/${NC}"
echo ""
print_warning "IMPORTANTE: Configura DNS de ${DOMAIN} apuntando a ${VPS_IP}"
echo ""
print_info "Comandos útiles:"
echo "  - Ver logs:       ./.deploy/logs.sh"
echo "  - Ver estado:     ./.deploy/status.sh"
echo "  - Reiniciar:      ./.deploy/restart.sh"
echo "  - Configurar DNS: ./.deploy/setup-dns.sh"
echo "  - Setup SSL:      ./.deploy/setup-ssl.sh"
echo ""
print_docker "Contenedores Docker:"
echo "  - thalamus_app (Elixir/Phoenix)"
echo "  - thalamus_postgres (PostgreSQL 16)"
echo "  - thalamus_redis (Redis 7)"
echo ""
