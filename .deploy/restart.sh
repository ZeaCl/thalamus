#!/bin/bash

# Script para reiniciar Thalamus

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

print_header "REINICIAR THALAMUS"

echo "Selecciona qué reiniciar:"
echo "  1) Solo Thalamus App (Elixir/Phoenix)"
echo "  2) Solo Database (PostgreSQL)"
echo "  3) Solo Redis"
echo "  4) Todos los contenedores"
echo "  5) Nginx"
echo "  6) TODO (Contenedores + Nginx)"
echo ""
read -p "Opción [1-6]: " option

case $option in
    1)
        print_info "Reiniciando Thalamus App..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "cd ${REMOTE_DIR} && docker compose restart thalamus"
        print_step "Thalamus App reiniciado"
        ;;
    2)
        print_warning "Reiniciando Database (esto puede afectar conexiones activas)..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "cd ${REMOTE_DIR} && docker compose restart postgres"
        print_step "Database reiniciada"
        ;;
    3)
        print_info "Reiniciando Redis..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "cd ${REMOTE_DIR} && docker compose restart redis"
        print_step "Redis reiniciado"
        ;;
    4)
        print_info "Reiniciando todos los contenedores..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "cd ${REMOTE_DIR} && docker compose restart"
        print_step "Contenedores reiniciados"
        ;;
    5)
        print_info "Reiniciando Nginx..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "systemctl restart nginx"
        print_step "Nginx reiniciado"
        ;;
    6)
        print_info "Reiniciando TODO..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" << EOF
cd ${REMOTE_DIR}
docker compose restart
systemctl restart nginx
EOF
        print_step "Todo reiniciado"
        ;;
    *)
        print_error "Opción inválida"
        exit 1
        ;;
esac

echo ""
print_info "Esperando 5 segundos para que los servicios se estabilicen..."
sleep 5

echo ""
print_info "Estado actual:"
ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
    "cd ${REMOTE_DIR} && docker compose ps"

echo ""
print_step "Reinicio completado"
print_info "Verifica el estado completo con: ./.deploy/status.sh"
