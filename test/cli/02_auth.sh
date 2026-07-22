#!/bin/bash
# Suite 02 — Auth: login, whoami, logout, debug
# Requiere: seeds con c@zea.cl / GusVicentAnto1.

# ═══ Setup helper ═══════════════════════════════════════
do_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." \
    --url "$THALAMUS_URL" > /dev/null 2>&1
}

# ── TC-05: Direct login — credenciales válidas ─────────────
log_test "TC-05: auth login directo — credenciales válidas"
output=$($CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." --url "$THALAMUS_URL" 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-05: exit 0"
assert_output_contains "$output" "Successfully authenticated\|authenticated" "TC-05: authenticated message"
assert_output_contains "$output" "c@zea.cl" "TC-05: shows user email"

# ── TC-06: Direct login — credenciales inválidas ───────────
log_test "TC-06: auth login directo — password inválida"
output=$($CLI_PATH thalamus auth login --email c@zea.cl --password "wrong" --url "$THALAMUS_URL" 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-06: exit 1"
assert_output_contains "$output" "Invalid\|invalid\|failed\|Failed" "TC-06: error message"

# ── TC-07: Direct login — email no existe ──────────────────
log_test "TC-07: auth login directo — email no existe"
output=$($CLI_PATH thalamus auth login --email noexiste@test.com --password "x" --url "$THALAMUS_URL" 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-07: exit 1"
assert_output_contains "$output" "Invalid\|invalid\|failed\|Failed\|not found" "TC-07: error message"

# ── TC-08: Login — parámetros faltantes ────────────────────
log_test "TC-08: auth login directo — sin password"
output=$($CLI_PATH thalamus auth login --email c@zea.cl --url "$THALAMUS_URL" 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-08: exit 1"
assert_output_contains "$output" "password\|required\|missing\|error" "TC-08: pide password"

# ── TC-09: Whoami — token válido ───────────────────────────
log_test "TC-09: whoami — después de login exitoso"
do_login
output=$($CLI_PATH thalamus auth whoami 2>&1)
assert_output_contains "$output" "c@zea.cl" "TC-09: email visible"
assert_output_contains "$output" "ZEA" "TC-09: org visible"

# ── TC-10: Whoami — sin token ──────────────────────────────
log_test "TC-10: whoami — sin token guardado"
clean_config
output=$($CLI_PATH thalamus auth whoami 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-10: exit 1"
assert_output_contains "$output" "Not authenticated\|not authenticated\|login\|Login" "TC-10: sugiere login"

# ── TC-11: Auth debug — JWT decode ─────────────────────────
log_test "TC-11: auth debug — decodifica JWT"
do_login
token=$(cat ~/.config/zea/config.json 2>/dev/null | jq -r '.token' 2>/dev/null) || true
if [ -n "$token" ] && [ "$token" != "null" ]; then
  output=$($CLI_PATH thalamus auth debug "$token" --output json 2>&1)
  assert_json_field "$output" '.server_status.active' 'true' "TC-11: token activo en servidor"
else
  log_fail "TC-11" "no se pudo leer token del config"
fi

# ── TC-12: Logout ──────────────────────────────────────────
log_test "TC-12: auth logout"
do_login
output=$($CLI_PATH thalamus auth logout 2>&1)
assert_output_contains "$output" "Logged out\|logged out\|revoked" "TC-12: logout message"
# Verificar que whoami falla después
output=$($CLI_PATH thalamus auth whoami 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-12: whoami fails after logout"
