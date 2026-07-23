#!/bin/bash
# Suite 04 — OAuth2 Clients: create, list, show, validate, rotate-secret, delete
# Requiere: login + org ZEA activa

do_login() {
  $CLI_PATH thalamus auth login --email admin@zea.local --password "Admin123!" \
    --url "$THALAMUS_URL" > /dev/null 2>&1
  $CLI_PATH thalamus org switch zea > /dev/null 2>&1
}

CLIENT_ID=""
CLIENT_SECRET=""

# ── TC-19: Client create — confidential ────────────────────
log_test "TC-19: client create — confidential"
do_login
output=$($CLI_PATH thalamus client create \
  --name "E2E Test Client" \
  --type confidential \
  --redirect-uris "http://localhost:9999/callback" \
  --grants "authorization_code,refresh_token" \
  --scopes "openid,profile,email" \
  --output json 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-19: exit 0"

CLIENT_ID=$(echo "$output" | jq -r '.data.id' 2>/dev/null)
CLIENT_SECRET=$(echo "$output" | jq -r '.data.client_secret' 2>/dev/null)

if [ -n "$CLIENT_ID" ] && [ "$CLIENT_ID" != "null" ]; then
  log_pass "TC-19: client_id=$CLIENT_ID"
else
  log_fail "TC-19" "no se obtuvo client_id"
fi

if [ -n "$CLIENT_SECRET" ] && [ "$CLIENT_SECRET" != "null" ]; then
  log_pass "TC-19: secret generado (${#CLIENT_SECRET} chars)"
else
  log_fail "TC-19" "no se generó client_secret"
fi

# ── TC-20: Client list — aparece ───────────────────────────
log_test "TC-20: client list — contiene E2E Test Client"
output=$($CLI_PATH thalamus client list --output json 2>&1)
assert_output_contains "$output" "E2E Test Client" "TC-20: aparece en lista"

# ── TC-21: Client show — detalle ───────────────────────────
log_test "TC-21: client show — detalle"
output=$($CLI_PATH thalamus client show "$CLIENT_ID" --output json 2>&1)
assert_json_field "$output" '.data.name' '"E2E Test Client"' "TC-21: nombre"
assert_json_field "$output" '.data.client_type' '"confidential"' "TC-21: tipo"

# ── TC-22: Client validate — OK ────────────────────────────
log_test "TC-22: client validate — PASS"
output=$($CLI_PATH thalamus client validate "$CLIENT_ID" --output json 2>&1)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
if [ "$status" = "pass" ] || [ "$status" = "PASS" ]; then
  log_pass "TC-22: status=$status"
else
  log_fail "TC-22" "expected pass, got $status"
fi

# ── TC-23: Client rotate-secret ────────────────────────────
log_test "TC-23: client rotate-secret"
output=$($CLI_PATH thalamus client rotate-secret "$CLIENT_ID" --output json 2>&1)
NEW_SECRET=$(echo "$output" | jq -r '.data.client_secret' 2>/dev/null)
if [ "$NEW_SECRET" != "$CLIENT_SECRET" ] && [ -n "$NEW_SECRET" ]; then
  log_pass "TC-23: secret rotado correctamente"
else
  log_fail "TC-23" "el secret no cambió o es vacío"
fi

# ── TC-24: Client create — redirect URI inválida ───────────
log_test "TC-24: client create — URI inválida"
output=$($CLI_PATH thalamus client create \
  --name "Invalid Client" \
  --redirect-uris "not-a-uri" \
  --output json 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-24: exit 1"
assert_output_contains "$output" "Invalid\|invalid\|error\|Error" "TC-24: error message"

# ── TC-25: Client create — sin parámetros obligatorios ─────
log_test "TC-25: client create — sin redirect URIs"
output=$($CLI_PATH thalamus client create \
  --name "No URI Client" \
  --output json 2>&1)
exit_code=$?
# Puede fallar o crear con defaults — verificamos que no crashee
assert_exit_code $exit_code 0 "TC-25: exit 0 (crea con defaults o falla controlado)"

# ── TC-26: Client delete — con confirmación ────────────────
log_test "TC-26: client delete"
output=$(echo "y" | $CLI_PATH thalamus client delete "$CLIENT_ID" 2>&1)
assert_output_contains "$output" "deleted\|Deleted\|deactivated\|removed" "TC-26: confirmación delete"

# Limpiar el client sin URI si se creó
NO_URI_ID=$(echo "$output" 2>/dev/null | jq -r '.data.id' 2>/dev/null) || true
