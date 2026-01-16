#!/bin/bash

# Script para configurar DNS de auth.zea.cl en Digital Ocean

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

print_header "CONFIGURANDO DNS PARA ${DOMAIN}"

# Verificar que tenemos el token
if [ -z "$DO_TOKEN" ]; then
    print_error "DO_TOKEN no está configurado en config.sh"
    exit 1
fi

# Extraer el dominio base (zea.cl) y el subdominio (auth)
SUBDOMAIN="${DOMAIN%%.*}"  # auth
BASE_DOMAIN="${DOMAIN#*.}" # zea.cl

print_info "Dominio base: ${BASE_DOMAIN}"
print_info "Subdominio: ${SUBDOMAIN}"
print_info "IP del VPS: ${VPS_IP}"

# Verificar si el dominio base existe en Digital Ocean
print_info "Verificando dominio ${BASE_DOMAIN} en Digital Ocean..."

DOMAIN_CHECK=$(curl -s -X GET "https://api.digitalocean.com/v2/domains/${BASE_DOMAIN}" \
  -H "Authorization: Bearer ${DO_TOKEN}" \
  -H "Content-Type: application/json")

if echo "$DOMAIN_CHECK" | grep -q "\"name\":\"${BASE_DOMAIN}\""; then
    print_step "Dominio ${BASE_DOMAIN} encontrado"
else
    print_error "Dominio ${BASE_DOMAIN} no encontrado en Digital Ocean"
    print_info "Por favor, agrega el dominio primero en: https://cloud.digitalocean.com/networking/domains"
    exit 1
fi

# Verificar si el registro A ya existe
print_info "Verificando si el registro ya existe..."

EXISTING_RECORD=$(curl -s -X GET "https://api.digitalocean.com/v2/domains/${BASE_DOMAIN}/records" \
  -H "Authorization: Bearer ${DO_TOKEN}" \
  -H "Content-Type: application/json" | \
  grep -o "\"name\":\"${SUBDOMAIN}\"")

if [ -n "$EXISTING_RECORD" ]; then
    print_warning "El registro ${SUBDOMAIN}.${BASE_DOMAIN} ya existe"
    read -p "¿Quieres eliminarlo y recrearlo? (s/n): " RECREATE

    if [ "$RECREATE" = "s" ]; then
        # Obtener ID del registro existente
        RECORD_ID=$(curl -s -X GET "https://api.digitalocean.com/v2/domains/${BASE_DOMAIN}/records" \
          -H "Authorization: Bearer ${DO_TOKEN}" \
          -H "Content-Type: application/json" | \
          python3 -c "import sys, json; records = json.load(sys.stdin)['domain_records']; print(next((r['id'] for r in records if r['name'] == '${SUBDOMAIN}'), ''))")

        if [ -n "$RECORD_ID" ]; then
            print_info "Eliminando registro existente (ID: ${RECORD_ID})..."
            curl -s -X DELETE "https://api.digitalocean.com/v2/domains/${BASE_DOMAIN}/records/${RECORD_ID}" \
              -H "Authorization: Bearer ${DO_TOKEN}"
            print_step "Registro eliminado"
            sleep 2
        fi
    else
        print_info "Manteniendo registro existente"
        exit 0
    fi
fi

# Crear el registro A
print_info "Creando registro A para ${SUBDOMAIN}.${BASE_DOMAIN} → ${VPS_IP}..."

RESPONSE=$(curl -s -X POST "https://api.digitalocean.com/v2/domains/${BASE_DOMAIN}/records" \
  -H "Authorization: Bearer ${DO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"A\",
    \"name\": \"${SUBDOMAIN}\",
    \"data\": \"${VPS_IP}\",
    \"ttl\": 1800
  }")

# Verificar si se creó correctamente
if echo "$RESPONSE" | grep -q "\"type\":\"A\""; then
    print_step "Registro DNS creado exitosamente"

    RECORD_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['domain_record']['id'])" 2>/dev/null || echo "N/A")
    print_info "Record ID: ${RECORD_ID}"
else
    print_error "Error al crear el registro DNS"
    echo "$RESPONSE" | python3 -m json.tool
    exit 1
fi

echo ""
print_step "DNS configurado correctamente"
echo ""
print_warning "IMPORTANTE: La propagación del DNS puede tomar entre 5-60 minutos"
echo ""
print_info "Puedes verificar la propagación con:"
echo "  dig ${DOMAIN}"
echo "  nslookup ${DOMAIN}"
echo ""
print_info "Una vez propagado, Thalamus estará disponible en:"
echo -e "  ${GREEN}http://${DOMAIN}/health${NC}"
echo -e "  ${GREEN}http://${DOMAIN}/${NC}"
echo ""
print_info "Siguiente paso: Configurar SSL con:"
echo "  ./.deploy/setup-ssl.sh"
echo ""
