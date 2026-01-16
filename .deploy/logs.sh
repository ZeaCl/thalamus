#!/bin/bash

# Script para ver logs de Thalamus

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

print_header "LOGS DE THALAMUS"

echo "Selecciona qué logs ver:"
echo "  1) Thalamus App (Elixir/Phoenix)"
echo "  2) Database (PostgreSQL)"
echo "  3) Cache (Redis)"
echo "  4) Todos los contenedores"
echo "  5) Nginx access log"
echo "  6) Nginx error log"
echo ""
read -p "Opción [1-6]: " option

case $option in
    1)
        print_info "Logs de Thalamus App (Elixir/Phoenix)..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "cd ${REMOTE_DIR} && docker compose logs -f --tail=100 thalamus"
        ;;
    2)
        print_info "Logs de PostgreSQL..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "cd ${REMOTE_DIR} && docker compose logs -f --tail=100 postgres"
        ;;
    3)
        print_info "Logs de Redis..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "cd ${REMOTE_DIR} && docker compose logs -f --tail=100 redis"
        ;;
    4)
        print_info "Logs de todos los contenedores..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "cd ${REMOTE_DIR} && docker compose logs -f --tail=100"
        ;;
    5)
        print_info "Nginx access log..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "tail -f /var/log/nginx/thalamus-access.log"
        ;;
    6)
        print_info "Nginx error log..."
        ssh -i "${SSH_KEY_PATH}" "${VPS_USER}@${VPS_IP}" \
            "tail -f /var/log/nginx/thalamus-error.log"
        ;;
    *)
        print_error "Opción inválida"
        exit 1
        ;;
esac
