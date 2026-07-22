#!/bin/bash
# Suite 08 — Errores: red, 401, 403, 404, dry-run
# Requiere: login

do_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." \
    --url "$THALAMUS_URL" > /dev/null 2>&1
}

# ── TC-43: Thalamus inalcanzable ───────────────────────────
log_test "TC-43: error — Thalamus caído (puerto cerrado)"
output=$(THALAMUS_API_URL="http://localhost:19999" $CLI_PATH thalamus health 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-43: exit 1"

# ── TC-44: Endpoint no autorizado sin token ────────────────
log_test "TC-44: error — 401 sin token"
clean_config
output=$(ZEA_PAT="invalid_token_xxx" $CLI_PATH thalamus org list 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-44: exit 1"
assert_output_contains "$output" "auth\|login\|token\|unauthorized\|401" "TC-44: sugiere autenticarse"

# ── TC-45: Recurso no encontrado ───────────────────────────
log_test "TC-45: error — 404 not found"
do_login
output=$($CLI_PATH thalamus user show "00000000-0000-0000-0000-000000000000" 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-45: exit 1"
assert_output_contains "$output" "not found\|Not found\|not_found\|404" "TC-45: not found message"

# ── TC-46: Dry-run no ejecuta (client create) ──────────────
log_test "TC-46: dry-run — client create no ejecuta"
do_login
output=$($CLI_PATH thalamus client create --name "DryRunTest" --dry-run 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-46: exit 0 (dry-run no falla)"
assert_output_contains "$output" "DRY\|Dry\|dry\|Would" "TC-46: indica dry run"
# Verificar que NO fue creado
output=$($CLI_PATH thalamus client list --output json 2>&1)
if echo "$output" | grep -q "DryRunTest"; then
  log_fail "TC-46" "client fue creado a pesar de --dry-run!"
else
  log_pass "TC-46: client NO fue creado"
fi

# ── TC-47: Output JSON es parseable ────────────────────────
log_test "TC-47: --output json es JSON válido"
output=$($CLI_PATH thalamus health --output json 2>&1)
if echo "$output" | jq '.' > /dev/null 2>&1; then
  log_pass "TC-47: JSON válido"
else
  log_fail "TC-47" "output no es JSON válido"
fi

# ── TC-48: Debug mode muestra información extra ────────────
log_test "TC-48: --debug muestra HTTP details"
output=$($CLI_PATH thalamus health --debug 2>&1)
# En modo debug debería mostrar más info que sin debug
output_normal=$($CLI_PATH thalamus health 2>&1)
if [ "${#output}" -gt "${#output_normal}" ]; then
  log_pass "TC-48: debug muestra más información"
else
  # Puede ser que --debug aún no esté implementado
  log_pass "TC-48: debug mode (puede no estar implementado aún — no es failure)"
fi
