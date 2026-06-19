#!/bin/bash

# ============================================
# CONFIGURACIÓN PARA DEPLOYMENT DE THALAMUS
# OAuth2 as a Service
# ============================================
# IMPORTANTE: Actualiza estos valores antes de hacer deploy

# ============================================
# INFORMACIÓN DEL VPS (Digital Ocean)
# ============================================
VPS_IP="104.236.120.97"                              # IP del Droplet
VPS_USER="root"                                       # Usuario SSH
SSH_KEY_PATH="/Users/dev/.ssh/id_ed25519"           # Path a tu SSH key

# ============================================
# CONFIGURACIÓN DE DIGITAL OCEAN
# ============================================
DO_TOKEN="dop_v1_548295408154cc50fbbb8d04b3f15e531ad018508d82e188018735e0be28c8b6"

# ============================================
# CONFIGURACIÓN DEL PROYECTO
# ============================================
PROJECT_NAME="thalamus"                               # Nombre del proyecto
DOMAIN="auth.zea.cl"                                  # Dominio principal
API_PORT="4000"                                       # Puerto de Phoenix (interno)
REMOTE_DIR="/opt/thalamus"                           # Directorio en el VPS

# ============================================
# CONFIGURACIÓN DE BASE DE DATOS
# ============================================
POSTGRES_USER="thalamus"
POSTGRES_DB="thalamus_prod"
POSTGRES_PASSWORD="Thalamus2026SecurePassword!"      # CAMBIAR en producción

# ============================================
# CONFIGURACIÓN DE REDIS
# ============================================
REDIS_PASSWORD="ThalamusRedis2026Secure!"            # CAMBIAR en producción

# ============================================
# SECRETOS DE APLICACIÓN (GENERAR NUEVOS)
# ============================================
# Generar con: mix phx.gen.secret
SECRET_KEY_BASE="ERn8l7ajCf9oZKjSsxXeLxHXxAuLm64KXOFEk9VS43H8SEUrHaYwuBcRluOkLjDK"
VERIFICATION_TOKEN_SECRET="9C4I9bvI/KWwBzHzK+8YHm1jDtbXj9Im1A8zmnDqEZpg5WOIZlemb/O338Aj5jh+"
PASSWORD_RESET_SECRET="GS0ZBmQYIyZBdBB1nd784R+m6YWHPJS7LvtRI08UH0Yf1N+qTgx1LJ9phiKBhpk/"
SESSION_SECRET="utBSs788hZvJ3rTlOAHeqlrRfzG6JAt19fuVyH4c315PzjqRAc5LCt0jYIpiSl9v"

# ============================================
# CONFIGURACIÓN DE EMAIL
# ============================================
EMAIL_FROM="noreply@zea.cl"
EMAIL_FROM_NAME="ZEA Thalamus"
EMAIL_BASE_URL="https://${DOMAIN}"

# SMTP (opcional - configurar si usas SMTP externo)
SMTP_HOST=""                                         # ej: smtp.sendgrid.net
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASSWORD=""

# ============================================
# CORS ORIGINS
# ============================================
# Lista de dominios permitidos (separados por coma)
CORS_ORIGINS="https://${DOMAIN},https://app.zea.cl,http://localhost:3000"

# ============================================
# CONFIGURACIÓN DE LOGS
# ============================================
LOG_LEVEL="info"                                     # debug, info, warning, error

# ============================================
# COLORES PARA OUTPUT
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================
# FUNCIONES DE UTILIDAD
# ============================================

print_header() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}============================================${NC}"
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_docker() {
    echo -e "${MAGENTA}[🐳]${NC} $1"
}

# ============================================
# VALIDACIÓN DE CONFIGURACIÓN
# ============================================
validate_config() {
    local errors=0

    # Verificar que los secretos hayan sido cambiados
    if [[ "$SECRET_KEY_BASE" == *"CHANGE_ME"* ]]; then
        print_error "SECRET_KEY_BASE no ha sido configurado"
        print_info "Genera uno con: mix phx.gen.secret"
        ((errors++))
    fi

    if [[ "$VERIFICATION_TOKEN_SECRET" == *"CHANGE_ME"* ]]; then
        print_error "VERIFICATION_TOKEN_SECRET no ha sido configurado"
        ((errors++))
    fi

    if [[ "$PASSWORD_RESET_SECRET" == *"CHANGE_ME"* ]]; then
        print_error "PASSWORD_RESET_SECRET no ha sido configurado"
        ((errors++))
    fi

    if [[ "$SESSION_SECRET" == *"CHANGE_ME"* ]]; then
        print_error "SESSION_SECRET no ha sido configurado"
        ((errors++))
    fi

    # Verificar contraseñas por defecto
    if [[ "$POSTGRES_PASSWORD" == "Thalamus2026SecurePassword!" ]]; then
        print_warning "POSTGRES_PASSWORD está usando el valor por defecto"
        print_info "Considera cambiarla por una más segura"
    fi

    if [[ "$REDIS_PASSWORD" == "ThalamusRedis2026Secure!" ]]; then
        print_warning "REDIS_PASSWORD está usando el valor por defecto"
        print_info "Considera cambiarla por una más segura"
    fi

    if [ $errors -gt 0 ]; then
        echo ""
        print_error "Hay $errors errores de configuración que deben corregirse"
        return 1
    fi

    return 0
}

# ============================================
# INFORMACIÓN DE VERSIÓN
# ============================================
DEPLOY_VERSION="1.0.0"
ELIXIR_VERSION="1.17"
PHOENIX_VERSION="1.8"

print_info "Thalamus Deployment Config v${DEPLOY_VERSION}"
print_info "Elixir ${ELIXIR_VERSION} + Phoenix ${PHOENIX_VERSION}"
