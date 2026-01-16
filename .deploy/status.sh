#!/bin/bash

# Script para ver el estado de Thalamus

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

print_header "ESTADO DE THALAMUS"

ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" << EOF
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\${CYAN}============================================\${NC}"
echo -e "\${CYAN}DOCKER CONTAINERS\${NC}"
echo -e "\${CYAN}============================================\${NC}"
cd ${REMOTE_DIR}
docker compose ps

echo ""
echo -e "\${CYAN}============================================\${NC}"
echo -e "\${CYAN}RECURSOS DEL SISTEMA\${NC}"
echo -e "\${CYAN}============================================\${NC}"

# CPU y RAM
echo -e "\${BLUE}CPU y RAM:\${NC}"
top -bn1 | head -5

echo ""
echo -e "\${BLUE}Uso de disco:\${NC}"
df -h / | tail -1

echo ""
echo -e "\${BLUE}Memoria detallada:\${NC}"
free -h

echo ""
echo -e "\${CYAN}============================================\${NC}"
echo -e "\${CYAN}DOCKER STATS (Uso de contenedores)\${NC}"
echo -e "\${CYAN}============================================\${NC}"
docker stats --no-stream thalamus_app thalamus_postgres thalamus_redis 2>/dev/null || echo "Contenedores no encontrados"

echo ""
echo -e "\${CYAN}============================================\${NC}"
echo -e "\${CYAN}SERVICIOS\${NC}"
echo -e "\${CYAN}============================================\${NC}"

# Verificar Nginx
if systemctl is-active --quiet nginx; then
    echo -e "\${GREEN}[✓]\${NC} Nginx: activo"
else
    echo -e "\${YELLOW}[!]\${NC} Nginx: inactivo"
fi

# Verificar Docker
if systemctl is-active --quiet docker; then
    echo -e "\${GREEN}[✓]\${NC} Docker: activo"
else
    echo -e "\${YELLOW}[!]\${NC} Docker: inactivo"
fi

echo ""
echo -e "\${CYAN}============================================\${NC}"
echo -e "\${CYAN}HEALTH CHECKS\${NC}"
echo -e "\${CYAN}============================================\${NC}"

# API health
if curl -s http://localhost:${API_PORT}/health > /dev/null; then
    echo -e "\${GREEN}[✓]\${NC} Thalamus health check: OK"
else
    echo -e "\${YELLOW}[!]\${NC} Thalamus health check: FAIL"
fi

# Database health
if docker exec thalamus_postgres pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} > /dev/null 2>&1; then
    echo -e "\${GREEN}[✓]\${NC} Database: conectada"
else
    echo -e "\${YELLOW}[!]\${NC} Database: error"
fi

# Redis health
if docker exec thalamus_redis redis-cli -a ${REDIS_PASSWORD} ping > /dev/null 2>&1; then
    echo -e "\${GREEN}[✓]\${NC} Redis: conectado"
else
    echo -e "\${YELLOW}[!]\${NC} Redis: error"
fi

echo ""
echo -e "\${CYAN}============================================\${NC}"
echo -e "\${CYAN}PUERTOS ESCUCHANDO\${NC}"
echo -e "\${CYAN}============================================\${NC}"
netstat -tuln | grep -E ':80|:${API_PORT}|:5432|:6379'

echo ""
EOF

print_info "Para ver logs en tiempo real: ./.deploy/logs.sh"
print_info "Para reiniciar servicios: ./.deploy/restart.sh"
