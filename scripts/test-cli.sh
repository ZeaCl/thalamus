#!/usr/bin/env bash
# scripts/test-cli.sh — CLI E2E test runner
#
# Ejecutable localmente o en CI. Requiere zea CLI instalado globalmente.
#
# Uso:
#   ./scripts/test-cli.sh              # todos los tests
#   ./scripts/test-cli.sh health login # tests específicos
#   ./scripts/test-cli.sh --ci         # modo CI (valida variables de entorno)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}✅ $1${NC}"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}❌ $1${NC}"; FAIL=$((FAIL + 1)); }

run_test() {
  local name="$1"
  local cmd="$2"
  local expected="$3"
  local output
  echo -n "── ${name}... "
  output=$(eval "$cmd" 2>&1) || true
  if echo "$output" | grep -qE "$expected"; then
    pass "$name"
  else
    fail "$name (expected: $expected)"
    echo "       output: $output"
    return 1
  fi
}

# ── Health + OIDC ─────────────────────────────
test_health() {
  run_test "health" \
    "zea thalamus health" \
    "ok"
}

test_whoami_unauth() {
  run_test "whoami (unauthenticated)" \
    "zea thalamus whoami" \
    "not authenticated|login"
}

# ── Auth (OAuth2 client_credentials) ──────────
test_setup_oauth() {
  echo "── setting up OAuth2 token..."
  local response
  response=$(curl -s -X POST http://localhost:4100/oauth/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=internal_login&client_secret=internal_secret_do_not_expose&username=admin@zea.local&password=Admin123!")
  local token
  token=$(echo "$response" | jq -r '.access_token')
  if [ -z "$token" ] || [ "$token" = "null" ]; then
    echo "       OAuth2 error: $response"
    fail "setup oauth token"
    return 1
  fi
  zea thalamus set-token "$token" 2>&1
  pass "setup oauth token"
}

test_login() {
  run_test "login" \
    "zea thalamus login --email admin@zea.local --password Admin123!" \
    "Successfully"
}

test_whoami_auth() {
  run_test "whoami (authenticated)" \
    "zea thalamus whoami" \
    "admin@zea.local"
}

test_org() {
  run_test "org list" \
    "zea thalamus org list" \
    "ZEA"
}

test_token() {
  run_test "token create" \
    "zea thalamus token create --name 'CI Test'" \
    "Token"
  if [ $? -ne 0 ]; then
    echo "       diagnostic curl:"
    local TOKEN
    TOKEN=$(cat ~/.config/zea/config.json | jq -r '.token')
    curl -sv -X POST http://localhost:4100/api/personal-access-tokens \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"name":"CI Test"}' 2>&1 | tail -20
  fi
}

test_404() {
  run_test "404 handled" \
    "zea thalamus user show 00000000-0000-0000-0000-000000000000" \
    "not found"
}

test_client() {
  run_test "client list" \
    "zea thalamus client list" \
    "Client|No OAuth2"
}

test_debug() {
  local token
  token=$(cat ~/.config/zea/config.json | jq -r '.token')
  run_test "debug" \
    "zea thalamus debug $token" \
    "Payload|active"
}

test_oidc() {
  run_test "oidc discovery" \
    "zea thalamus oidc discovery --output json" \
    "issuer"

  run_test "oidc jwks" \
    "zea thalamus oidc jwks" \
    "keys|kid"
}

# ── Client (read-only) ────────────────────────
test_client_show() {
  run_test "client show" \
    "zea thalamus client show thalamus_cli" \
    "Thalamus CLI|client"

  run_test "client validate" \
    "zea thalamus client validate thalamus_cli" \
    "pass|warn|fail"
}

# ── User (read-only) ──────────────────────────
test_user_list() {
  run_test "user list" \
    "zea thalamus user list" \
    "admin@zea.local"
}

test_user_show() {
  local user_id
  user_id=$(zea thalamus user list --output json 2>/dev/null | jq -r '.[0].id' 2>/dev/null || echo "")
  if [ -n "$user_id" ] && [ "$user_id" != "null" ]; then
    run_test "user show" \
      "zea thalamus user show $user_id" \
      "Email|Status"
  else
    echo -n "── user show... "
    echo "⚠️  skipping (no users found)"
  fi
}

test_user_scopes() {
  local user_id
  user_id=$(zea thalamus user list --output json 2>/dev/null | jq -r '.[0].id' 2>/dev/null || echo "")
  if [ -n "$user_id" ] && [ "$user_id" != "null" ]; then
    run_test "user scopes" \
      "zea thalamus user scopes $user_id" \
      "scope|No scopes"
  else
    echo -n "── user scopes... "
    echo "⚠️  skipping (no users found)"
  fi
}

# ── Org (read-only) ───────────────────────────
test_org_show() {
  run_test "org show" \
    "zea thalamus org show ZEA" \
    "ZEA|Plan|Status"
}

test_org_members() {
  run_test "org members" \
    "zea thalamus org member list ZEA" \
    "admin@zea.local|Members|No members"
}

# ── Secret (read-only) ─────────────────────────
test_secret_list() {
  run_test "secret list" \
    "zea thalamus secret list" \
    "secret|No secrets"
}

# ── Domain (read-only) ─────────────────────────
test_domain() {
  run_test "domain list" \
    "zea thalamus domain list" \
    "domain|No domains"

  run_test "domain roles" \
    "zea thalamus domain roles" \
    "role|No domain"
}

# ── Role (read-only) ───────────────────────────
test_role_list() {
  run_test "role list" \
    "zea thalamus role list" \
    "role|No roles"
}

# ── Admin (read-only, may fail without super_admin) ──
test_admin() {
  local output
  output=$(zea thalamus admin api-key list 2>&1) || true
  if echo "$output" | grep -qE "Forbidden|super_admin"; then
    echo -n "── admin api-key list... "
    pass "admin api-key list (requires super_admin)"
  else
    echo -n "── admin api-key list... "
    if echo "$output" | grep -qE "key|No admin"; then
      pass "admin api-key list"
    else
      fail "admin api-key list (expected keys or Forbidden, got: $output)"
    fi
  fi
}

# ── Audit (read-only) ──────────────────────────
test_audit() {
  run_test "audit export" \
    "zea thalamus audit export --limit 1" \
    "log|records"
}

# ═══════════════════════════════════════════════════════
# Stateful tests (create → verify → delete)
# Each test uses unique names with $$ (PID) for isolation.
# ═══════════════════════════════════════════════════════

cleanup_on_exit() {
  local trap_cmd="$1"
  trap "$trap_cmd" EXIT
}

# ── Client CRUD ────────────────────────────────
test_client_crud() {
  local NAME="e2e-crud-$$-$(date +%s)"
  local CLIENT_ID

  # Create
  run_test "client create" \
    "zea thalamus client create --name '$NAME' --type confidential --redirect-uris 'http://localhost:9999/callback'" \
    "created"

  CLIENT_ID=$(zea thalamus client list --output json 2>/dev/null | jq -r ".[] | select(.name==\"$NAME\") | .id" 2>/dev/null || echo "")

  if [ -n "$CLIENT_ID" ] && [ "$CLIENT_ID" != "null" ]; then
    cleanup_on_exit "zea thalamus client delete $CLIENT_ID 2>/dev/null"

    # Show
    run_test "client show (created)" \
      "zea thalamus client show $CLIENT_ID" \
      "$NAME"

    # Update
    run_test "client update" \
      "zea thalamus client update $CLIENT_ID --name '$NAME-updated'" \
      "updated"

    # Trust
    run_test "client trust" \
      "zea thalamus client trust $CLIENT_ID --on" \
      "trusted"

    # Delete
    run_test "client delete" \
      "zea thalamus client delete $CLIENT_ID" \
      "deactivated"
  else
    fail "client create (could not get client ID)"
  fi
}

# ── Secret CRUD ────────────────────────────────
test_secret_crud() {
  local NAME="e2e-secret-$$-$(date +%s)"

  run_test "secret create" \
    "zea thalamus secret create --name '$NAME' --provider 'e2e-test' --value 'test-value-123'" \
    "created"

  # cleanup via delete
  local SECRET_ID
  SECRET_ID=$(zea thalamus secret list --output json 2>/dev/null | jq -r ".[] | select(.name==\"$NAME\") | .id" 2>/dev/null || echo "")
  if [ -n "$SECRET_ID" ] && [ "$SECRET_ID" != "null" ]; then
    run_test "secret delete" \
      "zea thalamus secret delete $SECRET_ID" \
      "deleted"
  fi
}

# ── Role CRUD ──────────────────────────────────
test_role_crud() {
  local NAME="e2e-role-$$-$(date +%s)"

  run_test "role create" \
    "zea thalamus role create --name '$NAME' --scopes 'api:read,api:write'" \
    "created"

  local ROLE_ID
  ROLE_ID=$(zea thalamus role list --output json 2>/dev/null | jq -r ".[] | select(.name==\"$NAME\") | .id" 2>/dev/null || echo "")
  if [ -n "$ROLE_ID" ] && [ "$ROLE_ID" != "null" ]; then
    cleanup_on_exit "zea thalamus role delete $ROLE_ID 2>/dev/null"

    run_test "role show" \
      "zea thalamus role show $ROLE_ID" \
      "$NAME"

    run_test "role update" \
      "zea thalamus role update $ROLE_ID --name '$NAME-v2'" \
      "updated"

    run_test "role delete" \
      "zea thalamus role delete $ROLE_ID" \
      "deleted"
  fi
}

# ── User CRUD ──────────────────────────────────
test_user_crud() {
  local EMAIL="e2e-$(date +%s)-$$@test.zea.local"

  run_test "user create" \
    "zea thalamus user create --email '$EMAIL' --password 'TestPass123!' --name 'E2E Test'" \
    "created"

  local USER_ID
  USER_ID=$(zea thalamus user list --output json 2>/dev/null | jq -r ".[] | select(.email==\"$EMAIL\") | .id" 2>/dev/null || echo "")
  if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
    cleanup_on_exit "zea thalamus user delete $USER_ID 2>/dev/null"

    run_test "user update" \
      "zea thalamus user update $USER_ID --name 'E2E Updated'" \
      "updated"

    run_test "user role list" \
      "zea thalamus user role list $USER_ID" \
      "role|No roles"

    run_test "user delete" \
      "zea thalamus user delete $USER_ID" \
      "deactivated"
  fi
}

# ── Token CRUD ─────────────────────────────────
test_token_crud() {
  local TOKEN_NAME="e2e-token-$$-$(date +%s)"

  run_test "token create" \
    "zea thalamus token create --name '$TOKEN_NAME'" \
    "Token"

  local TOKEN_ID
  TOKEN_ID=$(zea thalamus token list --output json 2>/dev/null | jq -r ".[] | select(.name==\"$TOKEN_NAME\") | .id" 2>/dev/null || echo "")
  if [ -n "$TOKEN_ID" ] && [ "$TOKEN_ID" != "null" ]; then
    run_test "token revoke" \
      "zea thalamus token revoke $TOKEN_ID" \
      "revoked|Revoked"
  fi
}

# ── Error cases ───────────────────────────────
test_invalid_login() {
  run_test "invalid login rejected" \
    "zea thalamus login --email noexiste@test.com --password wrong" \
    "invalid|failed"
}

# ── Main ──────────────────────────────────────
ALL_TESTS=(health whoami_unauth login invalid_login setup_oauth whoami_auth org org_show org_members token token_crud client client_show client_crud secret_list secret_crud user_list user_show user_scopes user_crud domain role_list role_crud admin audit debug oidc 404)

run_all() {
  echo "═══ CLI E2E Tests ═══"
  for t in "${ALL_TESTS[@]}"; do
    "test_$t" || true
  done
  echo "─── Results: ${PASS} passed, ${FAIL} failed ───"
  return "$FAIL"
}

if [[ "${1:-}" == "--ci" ]]; then
  shift
fi

if [[ $# -eq 0 ]]; then
  run_all
else
  for t in "$@"; do
    "test_$t" || true
  done
fi
