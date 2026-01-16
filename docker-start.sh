#!/bin/bash

# ============================================================================
# Thalamus v1.0.0 - Docker Quick Start Script
# ============================================================================
# Este script facilita el inicio de Thalamus con Docker
# ============================================================================

set -e

echo "🐳 Thalamus v1.0.0 - Docker Quick Start"
echo "========================================"
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar que docker-compose está instalado
if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose no está instalado"
    echo "Instala Docker Desktop desde: https://www.docker.com/products/docker-desktop"
    exit 1
fi

print_success "Docker Compose detectado"

# Verificar si hay servicios corriendo
if docker-compose ps | grep -q "Up"; then
    print_warning "Servicios de Thalamus ya están corriendo"
    echo ""
    read -p "¿Quieres reiniciar los servicios? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Reiniciando servicios..."
        docker-compose down
    else
        echo "ℹ️  Saliendo sin cambios"
        echo ""
        echo "URLs de acceso:"
        echo "  Dashboard:  http://localhost:4100/dashboard"
        echo "  Mailbox:    http://localhost:4100/dev/mailbox"
        echo "  Adminer:    http://localhost:8180"
        exit 0
    fi
fi

# Iniciar servicios
echo ""
echo "🚀 Iniciando servicios de Thalamus..."
echo ""
docker-compose up -d

# Esperar a que los servicios estén listos
echo ""
echo "⏳ Esperando que los servicios estén listos..."
sleep 5

# Verificar estado de servicios
echo ""
echo "📊 Estado de los servicios:"
docker-compose ps

# Verificar health de PostgreSQL
echo ""
echo "🔍 Verificando PostgreSQL..."
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
        print_success "PostgreSQL está listo"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "PostgreSQL no respondió a tiempo"
        exit 1
    fi
    sleep 1
done

# Verificar health de Redis
echo ""
echo "🔍 Verificando Redis..."
if docker-compose exec -T redis redis-cli -a redis_password ping > /dev/null 2>&1; then
    print_success "Redis está listo"
else
    print_warning "Redis no respondió"
fi

# Esperar a que Thalamus compile
echo ""
echo "⏳ Esperando que Thalamus compile (esto puede tomar 1-2 minutos la primera vez)..."
sleep 10

# Verificar si Thalamus está respondiendo
echo ""
echo "🔍 Verificando Thalamus..."
MAX_ATTEMPTS=30
for i in $(seq 1 $MAX_ATTEMPTS); do
    if curl -s http://localhost:4100/api/public/health > /dev/null 2>&1; then
        print_success "Thalamus está respondiendo"
        break
    fi
    if [ $i -eq $MAX_ATTEMPTS ]; then
        print_warning "Thalamus está tardando en responder"
        echo "Puedes ver los logs con: docker-compose logs -f thalamus"
        break
    fi
    sleep 2
done

# Mostrar información de acceso
echo ""
echo "========================================"
echo "✅ Thalamus v1.0.0 está corriendo!"
echo "========================================"
echo ""
echo "📱 URLs de Acceso:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🏠 Dashboard:        http://localhost:4100/dashboard"
echo "  🔐 Login:            http://localhost:4100/login"
echo "  📧 Email Preview:    http://localhost:4100/dev/mailbox"
echo "  🔑 API Keys:         http://localhost:4100/dashboard/api-keys"
echo "  ⚙️  Settings:         http://localhost:4100/dashboard/settings"
echo "  🗄️  Adminer (DB):     http://localhost:8180"
echo "  📮 Redis Commander:  http://localhost:8181"
echo ""
echo "🔑 Credenciales de PostgreSQL (Adminer):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Sistema:   PostgreSQL"
echo "  Servidor:  postgres"
echo "  Usuario:   postgres"
echo "  Password:  postgres"
echo "  Database:  thalamus_dev"
echo ""
echo "📊 Comandos Útiles:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Ver logs:           docker-compose logs -f thalamus"
echo "  Ver todos los logs: docker-compose logs -f"
echo "  Detener:            docker-compose down"
echo "  IEx console:        docker-compose exec thalamus iex -S mix"
echo ""
echo "📖 Documentación:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Quick Start:        DOCKER_QUICK_START.md"
echo "  Dashboard Guide:    docs/guides/dashboard-user-guide.md"
echo "  Email Config:       docs/EMAIL_CONFIGURATION.md"
echo ""
echo "🎉 ¡Listo para probar la v1.0.0!"
echo ""
