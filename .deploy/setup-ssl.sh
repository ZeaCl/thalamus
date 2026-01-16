#!/bin/bash

# Script para configurar SSL/HTTPS con Let's Encrypt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

print_header "CONFIGURANDO SSL PARA ${DOMAIN}"

# Verificar que el DNS esté propagado
print_info "Verificando DNS..."
DNS_IP=$(dig +short ${DOMAIN} @8.8.8.8 | head -1)

if [ "$DNS_IP" != "$VPS_IP" ]; then
    print_error "El DNS no está apuntando a la IP correcta"
    print_info "DNS resuelve a: ${DNS_IP}"
    print_info "Debería resolver a: ${VPS_IP}"
    echo ""
    print_warning "Espera a que el DNS se propague completamente antes de configurar SSL"
    exit 1
fi

print_step "DNS apuntando correctamente a ${VPS_IP}"

# Verificar que la API responda por HTTP
print_info "Verificando que Thalamus responda..."
HTTP_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://${DOMAIN}/health)

if [ "$HTTP_CHECK" != "200" ]; then
    print_error "Thalamus no responde en http://${DOMAIN}/health (HTTP ${HTTP_CHECK})"
    exit 1
fi

print_step "Thalamus respondiendo correctamente"

echo ""
print_warning "IMPORTANTE: Let's Encrypt tiene límites de tasa"
print_info "- Máximo 5 certificados fallidos por semana"
print_info "- No uses esto en pruebas repetitivas"
echo ""
read -p "¿Continuar con la configuración de SSL? (s/n): " CONTINUE

if [ "$CONTINUE" != "s" ]; then
    print_info "Configuración cancelada"
    exit 0
fi

# Configurar SSL en el VPS
print_header "Instalando Certbot y configurando SSL"

ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" << EOF
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\${BLUE}[i]\${NC} Instalando Certbot..."

# Instalar certbot y plugin de nginx
apt-get update -qq
apt-get install -y certbot python3-certbot-nginx

echo -e "\${GREEN}[✓]\${NC} Certbot instalado"

# Limpiar cualquier intento previo de certificado para este dominio
echo -e "\${BLUE}[i]\${NC} Limpiando intentos previos de certificados..."
certbot delete --cert-name ${DOMAIN} --non-interactive 2>/dev/null || true

# Verificar que nginx tenga el bloque ACME challenge
echo -e "\${BLUE}[i]\${NC} Verificando configuración de Nginx..."
if ! grep -q "/.well-known/acme-challenge" /etc/nginx/sites-enabled/${PROJECT_NAME}; then
    echo -e "\${YELLOW}[!]\${NC} Configuración ACME ya está presente en nginx"
fi

echo -e "\${BLUE}[i]\${NC} Obteniendo certificado SSL de Let's Encrypt..."
echo -e "\${YELLOW}[!]\${NC} Esto puede tomar 1-2 minutos..."

# Obtener certificado
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email noreply@${DOMAIN} --redirect

if [ \$? -eq 0 ]; then
    echo -e "\${GREEN}[✓]\${NC} Certificado SSL obtenido exitosamente"

    # Configurar renovación automática
    echo -e "\${BLUE}[i]\${NC} Configurando renovación automática..."

    # Testear renovación
    certbot renew --dry-run

    echo -e "\${GREEN}[✓]\${NC} Renovación automática configurada"
else
    echo -e "\${RED}[✗]\${NC} Error al obtener el certificado SSL"
    exit 1
fi

# Recargar nginx
systemctl reload nginx

echo ""
echo -e "\${GREEN}============================================\${NC}"
echo -e "\${GREEN}SSL CONFIGURADO EXITOSAMENTE\${NC}"
echo -e "\${GREEN}============================================\${NC}"
EOF

if [ $? -eq 0 ]; then
    echo ""
    print_step "SSL configurado correctamente"
    echo ""
    print_info "Thalamus ahora está disponible en HTTPS:"
    echo -e "  ${GREEN}https://${DOMAIN}/health${NC}"
    echo -e "  ${GREEN}https://${DOMAIN}/${NC}"
    echo ""
    print_info "Verificando HTTPS..."

    sleep 3

    HTTPS_CHECK=$(curl -s -o /dev/null -w "%{http_code}" https://${DOMAIN}/health)

    if [ "$HTTPS_CHECK" = "200" ]; then
        print_step "HTTPS funcionando correctamente"

        echo ""
        print_info "Detalles del certificado:"
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" "certbot certificates"
    else
        print_warning "HTTPS no responde inmediatamente (HTTP ${HTTPS_CHECK})"
        print_info "Puede tomar unos segundos. Intenta: curl https://${DOMAIN}/health"
    fi

    echo ""
    print_info "Renovación automática:"
    print_step "Certbot renovará automáticamente el certificado cada 60 días"
    print_info "Puedes probar la renovación con: certbot renew --dry-run"

else
    print_error "Error al configurar SSL"
    exit 1
fi
