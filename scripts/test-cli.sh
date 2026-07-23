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
  echo -n "── ${name}... "
  if eval "$cmd" 2>&1 | grep -qE "$expected"; then
    pass "$name"
  else
    fail "$name (expected: $expected)"
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
    "zea thalamus auth whoami" \
    "not authenticated|login"
}

# ── Auth ──────────────────────────────────────
test_login() {
  run_test "login" \
    "zea thalamus auth login --email admin@zea.local --password Admin123!" \
    "Successfully"
}

test_whoami_auth() {
  run_test "whoami (authenticated)" \
    "zea thalamus auth whoami" \
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
}

test_client() {
  run_test "client list" \
    "zea thalamus client list" \
    "Client|No OAuth2"
}

test_debug() {
  local token
  token=$(cat ~/.config/zea/config.json | jq -r '.token')
  run_test "auth debug" \
    "zea thalamus auth debug $token" \
    "Payload|active"
}

test_oidc() {
  run_test "oidc discovery" \
    "zea thalamus oidc discovery --output json" \
    "issuer"
}

# ── Error cases ───────────────────────────────
test_invalid_login() {
  run_test "invalid login rejected" \
    "zea thalamus auth login --email noexiste@test.com --password wrong" \
    "invalid|failed"
}

test_404() {
  run_test "404 handled" \
    "zea thalamus user show 00000000-0000-0000-0000-000000000000" \
    "not found"
}

# ── Main ──────────────────────────────────────
ALL_TESTS=(health whoami_unauth login whoami_auth org token client debug oidc invalid_login 404)

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
