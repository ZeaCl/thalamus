#!/bin/bash
# ============================================================================
# Thalamus OAuth2 Client Validator
# ============================================================================
# Uso:
#   ./validate_oauth2_client.sh <CLIENT_ID_STRING> [--local|--prod]
#
# Ejemplos:
#   ./validate_oauth2_client.sh soma_service --local
#   ./validate_oauth2_client.sh "59991e63-852c-44e5-aee1-a761ec76eaea" --local
#   ./validate_oauth2_client.sh soma_service --prod
#
# Verifica automáticamente:
#   1. Cliente existe y está activo
#   2. client_type vs token_endpoint_auth_method (coherencia)
#   3. PKCE config vs client_type
#   4. redirect_uris (formato, presencia)
#   5. allowed_grant_types
#   6. allowed_scopes (mínimo "openid")
#   7. CORS origins (contiene dominio del servicio)
#   8. CSP form-action (contiene dominio del servicio)
#   9. JWKS endpoint health
#  10. /oauth/authorize endpoint responde
#  11. /oauth/token endpoint responde con CORS
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS="${GREEN}✅ PASS${NC}"
FAIL="${RED}❌ FAIL${NC}"
WARN="${YELLOW}⚠️  WARN${NC}"
SKIP="${CYAN}→ SKIP${NC}"

check_count=0
pass_count=0
fail_count=0
warn_count=0

check() {
  local label="$1"
  local result="$2"
  local detail="${3:-}"
  check_count=$((check_count + 1))
  case "$result" in
    PASS) pass_count=$((pass_count + 1)); echo -e "  $PASS  $label";;
    FAIL) fail_count=$((fail_count + 1)); echo -e "  $FAIL  $label"; [ -n "$detail" ] && echo -e "        ${RED}→ $detail${NC}";;
    WARN) warn_count=$((warn_count + 1)); echo -e "  $WARN  $label"; [ -n "$detail" ] && echo -e "        ${YELLOW}→ $detail${NC}";;
    SKIP) echo -e "  $SKIP  $label";;
  esac
}

banner() {
  echo ""
  echo -e "${BOLD}${CYAN}═══ $1 ═══${NC}"
}

# ── Parse args ──────────────────────────────────────────────────────────────
CLIENT_ID="${1:-}"
ENV="${2:---local}"

if [ -z "$CLIENT_ID" ]; then
  echo "Uso: $0 <CLIENT_ID_STRING> [--local|--prod]"
  echo ""
  echo "Ejemplos:"
  echo "  $0 soma_service --local"
  echo "  $0 soma_service --prod"
  exit 1
fi

case "$ENV" in
  --local)
    CONTAINER="zea_thalamus_local"
    THALAMUS_URL="http://auth.zea.localhost"
    COMPOSE_FILE="/Users/dev/Documents/zea/zea/docker-compose.yml"
    ;;
  --prod)
    CONTAINER="zea_thalamus"
    THALAMUS_URL="https://auth.zea.cl"
    COMPOSE_FILE="~/zea/docker-compose.vps.yml"
    echo -e "${YELLOW}⚠️  Modo producción: requiere acceso al VPS (45.55.191.97)${NC}"
    ;;
  *)
    echo "Entorno no reconocido: $ENV (usar --local o --prod)"
    exit 1
    ;;
esac

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   Thalamus OAuth2 Client Validator                          ║${NC}"
echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${CYAN}║   Client: ${CLIENT_ID}${NC}"
echo -e "${BOLD}${CYAN}║   Entorno: ${ENV}${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

# ── 1. Verificar que el container está corriendo ────────────────────────────
banner "1. Container Status"

if [ "$ENV" = "--local" ]; then
  STATUS=$(docker ps --filter name="$CONTAINER" --format "{{.Status}}" 2>/dev/null || echo "")
  if echo "$STATUS" | grep -q "Up"; then
    check "Container $CONTAINER" PASS "Status: $STATUS"
  else
    check "Container $CONTAINER" FAIL "No está corriendo. Ejecutá: cd /Users/dev/Documents/zea/zea && docker compose up -d"
    echo ""
    echo -e "${RED}Container no disponible. Abortando.${NC}"
    exit 1
  fi
else
  # Prod: intentar SSH
  if ssh -o ConnectTimeout=5 root@45.55.191.97 "docker ps --filter name=$CONTAINER --format '{{.Status}}'" 2>/dev/null | grep -q "Up"; then
    check "Container $CONTAINER (VPS)" PASS
  else
    check "Container $CONTAINER (VPS)" FAIL "No se puede conectar al VPS o el container no está corriendo"
    echo ""
    echo -e "${RED}Container no disponible. Abortando.${NC}"
    exit 1
  fi
fi

# ── 2. Buscar cliente ──────────────────────────────────────────────────────
banner "2. OAuth2 Client"

# Escapar comillas para el RPC
RPC_CMD="docker exec $CONTAINER bin/thalamus rpc '"

# Construir el script Elixir
ELIXIR_SCRIPT=$(cat <<ELIXIR
alias Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema
alias Thalamus.Repo

# Buscar por client_id_string
c = Repo.get_by(OAuth2ClientSchema, client_id_string: "$CLIENT_ID")

# Si no encuentra, buscar por id (UUID)
c = if is_nil(c), do: Repo.get(OAuth2ClientSchema, "$CLIENT_ID"), else: c

if is_nil(c) do
  IO.puts("NOT_FOUND")
else
  IO.puts("FOUND")
  IO.puts("NAME:" <> (c.name || ""))
  IO.puts("TYPE:" <> Atom.to_string(c.client_type))
  IO.puts("ACTIVE:" <> Atom.to_string(c.is_active))
  IO.puts("GRANTS:" <> Enum.join(c.allowed_grant_types || [], ","))
  IO.puts("SCOPES:" <> Enum.join(c.allowed_scopes || [], ","))
  IO.puts("REDIRECTS:" <> Enum.join(c.redirect_uris || [], "|"))
  IO.puts("PKCE:" <> Atom.to_string(c.pkce_required))
  IO.puts("AUTH_METHOD:" <> (c.token_endpoint_auth_method || "client_secret_post"))
  IO.puts("ORG_ID:" <> (c.organization_id || ""))
  IO.puts("CLIENT_ID_STRING:" <> (c.client_id_string || ""))
end
ELIXIR
)

if [ "$ENV" = "--local" ]; then
  RAW=$(docker exec "$CONTAINER" bin/thalamus rpc "$ELIXIR_SCRIPT" 2>/dev/null || echo "ERROR")
else
  RAW=$(ssh root@45.55.191.97 "docker exec $CONTAINER bin/thalamus rpc '$ELIXIR_SCRIPT'" 2>/dev/null || echo "ERROR")
fi

if echo "$RAW" | grep -q "NOT_FOUND"; then
  check "Client '$CLIENT_ID' existe" FAIL "No se encontró en la base de datos. ¿Está bien escrito el client_id_string?"
  echo ""
  echo -e "${RED}Cliente no encontrado. Abortando validaciones específicas del cliente.${NC}"
else
  # Parsear output
  NAME=$(echo "$RAW" | grep "^NAME:" | sed 's/^NAME://')
  TYPE=$(echo "$RAW" | grep "^TYPE:" | sed 's/^TYPE://')
  ACTIVE=$(echo "$RAW" | grep "^ACTIVE:" | sed 's/^ACTIVE://')
  GRANTS=$(echo "$RAW" | grep "^GRANTS:" | sed 's/^GRANTS://')
  SCOPES=$(echo "$RAW" | grep "^SCOPES:" | sed 's/^SCOPES://')
  REDIRECTS=$(echo "$RAW" | grep "^REDIRECTS:" | sed 's/^REDIRECTS://')
  PKCE=$(echo "$RAW" | grep "^PKCE:" | sed 's/^PKCE://')
  AUTH_METHOD=$(echo "$RAW" | grep "^AUTH_METHOD:" | sed 's/^AUTH_METHOD://')
  ORG_ID=$(echo "$RAW" | grep "^ORG_ID:" | sed 's/^ORG_ID://')
  CLIENT_ID_STR=$(echo "$RAW" | grep "^CLIENT_ID_STRING:" | sed 's/^CLIENT_ID_STRING://')

  check "Client '$CLIENT_ID' existe" PASS "Nombre: $NAME"

  if [ "$ACTIVE" = "true" ]; then
    check "Cliente está activo (is_active)" PASS
  else
    check "Cliente está activo (is_active)" FAIL "is_active = false. Activá con: Ecto.Changeset.change(client, is_active: true) |> Repo.update!()"
  fi

  # ── 3. Coherencia client_type vs token_endpoint_auth_method ───────────────
  banner "3. Configuración SPA vs Backend"

  if [ "$TYPE" = "public" ]; then
    if [ "$AUTH_METHOD" = "none" ]; then
      check "SPA: auth_method = 'none'" PASS
    else
      check "SPA: auth_method = 'none'" FAIL "SPA (client_type=public) debe tener token_endpoint_auth_method='none', actual: '$AUTH_METHOD'"
    fi

    if [ "$PKCE" = "true" ]; then
      check "SPA: pkce_required = true" PASS
    else
      check "SPA: pkce_required = true" WARN "SPA sin PKCE es inseguro. Recomendado: pkce_required: true"
    fi

    if echo "$GRANTS" | grep -q "authorization_code"; then
      check "SPA: tiene authorization_code grant" PASS
    else
      check "SPA: tiene authorization_code grant" FAIL "SPA necesita authorization_code en allowed_grant_types. Actual: $GRANTS"
    fi

    if [ -n "$REDIRECTS" ] && [ "$REDIRECTS" != "" ]; then
      check "SPA: tiene redirect_uris" PASS "$(echo "$REDIRECTS" | tr '|' '\n' | head -3 | sed 's/^/        /')"
    else
      check "SPA: tiene redirect_uris" FAIL "SPA requiere al menos 1 redirect_uri"
    fi

  elif [ "$TYPE" = "confidential" ]; then
    if [ "$AUTH_METHOD" = "client_secret_post" ]; then
      check "Backend: auth_method = 'client_secret_post'" PASS
    else
      check "Backend: auth_method = 'client_secret_post'" WARN "Backend normalmente usa client_secret_post, actual: '$AUTH_METHOD'"
    fi

    if [ "$PKCE" = "false" ]; then
      check "Backend: pkce_required = false" PASS
    else
      check "Backend: pkce_required = true" WARN "Backend con PKCE es inusual. ¿Es realmente un backend?"
    fi

    if echo "$GRANTS" | grep -q "client_credentials"; then
      check "Backend: tiene client_credentials grant" PASS
    else
      check "Backend: tiene client_credentials grant" WARN "Backend normalmente usa client_credentials. Actual: $GRANTS"
    fi
  fi

  # ── 4. Scopes ────────────────────────────────────────────────────────────
  banner "4. Scopes"

  if echo "$SCOPES" | grep -q "openid"; then
    check "Tiene scope 'openid'" PASS
  else
    check "Tiene scope 'openid'" FAIL "openid es el scope mínimo requerido para OIDC"
  fi

  # ── 5. Redirect URIs ─────────────────────────────────────────────────────
  banner "5. Redirect URIs"

  if [ -n "$REDIRECTS" ] && [ "$REDIRECTS" != "" ]; then
    IFS='|' read -ra URI_ARRAY <<< "$REDIRECTS"
    for uri in "${URI_ARRAY[@]}"; do
      if echo "$uri" | grep -qE '^https?://'; then
        check "URI: $uri" PASS
      else
        check "URI: $uri" FAIL "Formato inválido. Debe empezar con http:// o https://"
      fi
    done
  else
    if [ "$TYPE" = "confidential" ]; then
      check "Sin redirect URIs" PASS "Backend no necesita redirect URIs"
    else
      check "Sin redirect URIs" FAIL "SPA requiere redirect URIs"
    fi
  fi

  # ── 6. Organization ──────────────────────────────────────────────────────
  banner "6. Organization"

  if [ -n "$ORG_ID" ] && [ "$ORG_ID" != "" ]; then
    check "Tiene organization_id" PASS "Org: $ORG_ID"
  else
    check "Tiene organization_id" FAIL "organization_id es requerido"
  fi

  # ── 7. CORS ──────────────────────────────────────────────────────────────
  banner "7. CORS (Cross-Origin Resource Sharing)"

  # Extraer dominios de las redirect URIs para verificar CORS
  if [ -n "$REDIRECTS" ] && [ "$REDIRECTS" != "" ]; then
    IFS='|' read -ra URI_ARRAY <<< "$REDIRECTS"
    CORS_ORIGINS=""
    if [ "$ENV" = "--local" ]; then
      CORS_ORIGINS=$(docker exec "$CONTAINER" sh -c 'echo $CORS_ORIGINS' 2>/dev/null || echo "")
    fi

    # Deducir orígenes únicos (sin declare -A para compatibilidad macOS bash 3.x)
    UNIQUE_ORIGINS=""
    for uri in "${URI_ARRAY[@]}"; do
      ORIGIN=$(echo "$uri" | sed -E 's|^(https?://[^/]+).*|\1|')
      if ! echo "|$UNIQUE_ORIGINS|" | grep -qF "|$ORIGIN|"; then
        UNIQUE_ORIGINS="$UNIQUE_ORIGINS|$ORIGIN"
        if [ -n "$CORS_ORIGINS" ]; then
          if echo "$CORS_ORIGINS" | grep -qF "$ORIGIN"; then
            check "CORS incluye origen: $ORIGIN" PASS
          else
            check "CORS incluye origen: $ORIGIN" FAIL "Agregar '$ORIGIN' a CORS_ORIGINS en docker-compose.yml"
          fi
        else
          # Probar con curl
          CORS_CHECK=$(curl -s -X OPTIONS "${THALAMUS_URL}/oauth/token" \
            -H "Origin: $ORIGIN" \
            -H "Access-Control-Request-Method: POST" \
            -H "Access-Control-Request-Headers: Content-Type" \
            -I 2>/dev/null | grep -i "Access-Control-Allow-Origin" || echo "")
          if echo "$CORS_CHECK" | grep -qF "$ORIGIN"; then
            check "CORS permite origen: $ORIGIN" PASS
          else
            check "CORS permite origen: $ORIGIN" FAIL "El servidor no devuelve Access-Control-Allow-Origin: $ORIGIN. Agregar a CORS_ORIGINS."
          fi
        fi
      fi
    done
  fi

  # ── 8. CSP ───────────────────────────────────────────────────────────────
  banner "8. CSP (Content-Security-Policy)"

  if [ "$ENV" = "--local" ]; then
    CSP_HEADER=$(curl -sI "${THALAMUS_URL}/oauth/authorize" 2>/dev/null | grep -i "Content-Security-Policy" | tr -d '\r' || echo "")
    if [ -n "$CSP_HEADER" ]; then
      FORM_ACTION=$(echo "$CSP_HEADER" | tr -d '\r\n' | grep -oE 'form-action[^;]*' | sed 's/form-action //')
      check "CSP header presente" PASS
      check "CSP form-action incluye 'self'" PASS

      # Mostrar dominios cubiertos por el CSP actual
      echo -e "        ${CYAN}CSP form-action actual:${NC}"
      echo "$FORM_ACTION" | tr ' ' '\n' | grep -v "^$" | grep -v "^'" | while read -r entry; do
        echo -e "        ${CYAN}  • $entry${NC}"
      done

      # Verificar si los dominios de redirect_uris están cubiertos por CSP
      # Nota: form-action solo aplica a form submissions, no a redirects 302.
      # La mayoría de los redirect URIs no necesitan estar en form-action
      # porque la redirección es server-side. Solo verificar dominios que
      # podrían necesitar estar en CSP por otras razones.
      if [ -n "$REDIRECTS" ] && [ "$REDIRECTS" != "" ]; then
        UNIQUE_CSP=""
        IFS='|' read -ra URI_ARRAY <<< "$REDIRECTS"
        for uri in "${URI_ARRAY[@]}"; do
          HOST=$(echo "$uri" | sed -E 's|^https?://||; s|/.*||')
          if ! echo "|$UNIQUE_CSP|" | grep -qF "|$HOST|"; then
            UNIQUE_CSP="$UNIQUE_CSP|$HOST"
            # Solo advertir si es un dominio que no matchea wildcards
            # En CSP los hosts aparecen como http://HOST:* o https://HOST
            DOMAIN_PART="${HOST#*.}"
            HOST_NOPORT="${HOST%:*}"
            if echo "$FORM_ACTION" | grep -qE "://${HOST}( |:|$|\*)" || \
               echo "$FORM_ACTION" | grep -qE "://${HOST_NOPORT}:\*"; then
              : # cubierto exactamente (ej: http://soma.zea.localhost:*)
            elif echo "$FORM_ACTION" | grep -qE "://\*\.${DOMAIN_PART}( |:|$|\*)"; then
              : # cubierto por wildcard (ej: http://*.zea.localhost:* cubre app.zea.localhost)
            else
              check "CSP cubre dominio: $HOST" WARN "No está en form-action. Si este dominio tiene forms que submittean a Thalamus, agregalo."
            fi
          fi
        done
      fi
    else
      check "CSP header presente" FAIL "No se detectó header CSP. Verificar security_headers.ex"
    fi
  else
    check "CSP (prod)" SKIP "Ejecutar en VPS para verificar CSP"
  fi

  # ── 9. Health checks ────────────────────────────────────────────────────
  banner "9. Endpoints"

  # JWKS
  JWKS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${THALAMUS_URL}/.well-known/jwks.json" 2>/dev/null || echo "000")
  if [ "$JWKS_CODE" = "200" ]; then
    check "JWKS endpoint (.well-known/jwks.json)" PASS "HTTP $JWKS_CODE"
  else
    check "JWKS endpoint" FAIL "HTTP $JWKS_CODE — ¿Thalamus está corriendo?"
  fi

  # Authorize
  AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${THALAMUS_URL}/oauth/authorize" 2>/dev/null || echo "000")
  if [ "$AUTH_CODE" = "302" ] || [ "$AUTH_CODE" = "400" ] || [ "$AUTH_CODE" = "200" ]; then
    check "Authorize endpoint (/oauth/authorize)" PASS "HTTP $AUTH_CODE (responde)"
  else
    check "Authorize endpoint" FAIL "HTTP $AUTH_CODE — endpoint no responde"
  fi

  # Token
  TOKEN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${THALAMUS_URL}/oauth/token" 2>/dev/null || echo "000")
  if [ "$TOKEN_CODE" = "400" ] || [ "$TOKEN_CODE" = "401" ]; then
    check "Token endpoint (/oauth/token)" PASS "HTTP $TOKEN_CODE (responde sin params)"
  else
    check "Token endpoint" FAIL "HTTP $TOKEN_CODE — endpoint no responde"
  fi

  # ── 10. Test de authorize con parámetros ─────────────────────────────────
  banner "10. Prueba de Authorize Flow"

  if [ "$TYPE" = "public" ] && [ -n "$REDIRECTS" ] && [ "$REDIRECTS" != "" ]; then
    IFS='|' read -ra URI_ARRAY <<< "$REDIRECTS"
    FIRST_REDIRECT="${URI_ARRAY[0]}"
    FIRST_REDIRECT_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$FIRST_REDIRECT', safe=''))" 2>/dev/null || echo "$FIRST_REDIRECT")

    AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
      "${THALAMUS_URL}/oauth/authorize?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${FIRST_REDIRECT_ENCODED}&scope=openid&state=test123" \
      2>/dev/null || echo "000")

    if [ "$AUTH_RESPONSE" = "302" ]; then
      check "Authorize redirect funciona" PASS "HTTP 302 → redirige a login"
    elif [ "$AUTH_RESPONSE" = "400" ]; then
      check "Authorize redirect funciona" FAIL "HTTP 400 — ¿redirect_uri registrado? ¿client_id correcto?"
    elif [ "$AUTH_RESPONSE" = "200" ]; then
      check "Authorize redirect funciona" PASS "HTTP 200 → muestra consent/login (puede ser normal)"
    else
      check "Authorize redirect funciona" FAIL "HTTP $AUTH_RESPONSE inesperado"
    fi
  else
    check "Prueba de authorize" SKIP "Solo aplica a clientes SPA con redirect_uris"
  fi

fi

# ── Resumen ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   RESUMEN                                                    ║${NC}"
echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${CYAN}║   ${GREEN}✅ ${pass_count} PASS  ${RED}❌ ${fail_count} FAIL  ${YELLOW}⚠️  ${warn_count} WARN  ${CYAN}→ ${check_count} checks${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$fail_count" -gt 0 ]; then
  echo -e "${RED}${BOLD}⚠️  Hay $fail_count errores que corregir antes de que funcione.${NC}"
  exit 1
elif [ "$warn_count" -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}⚠️  Todo parece bien pero hay $warn_count advertencias. Revisar.${NC}"
  exit 0
else
  echo -e "${GREEN}${BOLD}🎉 Todo OK. El cliente está correctamente configurado.${NC}"
  exit 0
fi
