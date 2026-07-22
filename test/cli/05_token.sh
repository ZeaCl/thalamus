#!/bin/bash
# Suite 05 — Personal Access Tokens: create, list, revoke
# Requiere: login + org ZEA activa

do_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." \
    --url "$THALAMUS_URL" > /dev/null 2>&1
  $CLI_PATH thalamus org switch zea > /dev/null 2>&1
}

TOKEN_ID=""
TOKEN_VALUE=""

# ── TC-27: Token create ────────────────────────────────────
log_test "TC-27: token create"
do_login
output=$($CLI_PATH thalamus token create --name "E2E Test Token" --output json 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-27: exit 0"

TOKEN_ID=$(echo "$output" | jq -r '.data.id' 2>/dev/null)
TOKEN_VALUE=$(echo "$output" | jq -r '.token' 2>/dev/null)

if [ -n "$TOKEN_ID" ] && [ "$TOKEN_ID" != "null" ]; then
  log_pass "TC-27: token_id=$TOKEN_ID"
else
  log_fail "TC-27" "no se obtuvo token_id"
fi

if [ -n "$TOKEN_VALUE" ] && [ "${#TOKEN_VALUE}" -gt 10 ]; then
  log_pass "TC-27: token generado (${#TOKEN_VALUE} chars)"
else
  log_fail "TC-27" "token muy corto o vacío"
fi

# ── TC-28: Token list — contiene el token creado ───────────
log_test "TC-28: token list — contiene E2E Test Token"
output=$($CLI_PATH thalamus token list --output json 2>&1)
assert_output_contains "$output" "E2E Test Token" "TC-28: token en lista"

# ── TC-29: Usar PAT como ZEA_PAT ───────────────────────────
log_test "TC-29: usar PAT via ZEA_PAT env var"
output=$(ZEA_PAT="$TOKEN_VALUE" $CLI_PATH thalamus auth whoami --output json 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-29: whoami con PAT exit 0"
assert_output_contains "$output" "c@zea.cl" "TC-29: autenticado con PAT"

# ── TC-30: PAT inválido ────────────────────────────────────
log_test "TC-30: PAT inválido"
output=$(ZEA_PAT="th_pat_invalid_token_xxx" $CLI_PATH thalamus auth whoami 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-30: exit 1"

# ── TC-31: Token revoke ────────────────────────────────────
log_test "TC-31: token revoke"
output=$($CLI_PATH thalamus token revoke "$TOKEN_ID" 2>&1)
assert_output_contains "$output" "revoked\|Revoked\|ok" "TC-31: revoked message"

# ── TC-32: Token revocado ya no funciona ───────────────────
log_test "TC-32: token revocado — ya no autentica"
output=$(ZEA_PAT="$TOKEN_VALUE" $CLI_PATH thalamus auth whoami 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-32: exit 1 (token revocado)"
