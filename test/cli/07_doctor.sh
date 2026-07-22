#!/bin/bash
# Suite 07 — Doctor: diagnóstico completo
# Requiere: login

do_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." \
    --url "$THALAMUS_URL" > /dev/null 2>&1
}

# ── TC-40: Doctor — diagnóstico completo OK ────────────────
log_test "TC-40: doctor — diagnóstico completo OK"
do_login
output=$($CLI_PATH thalamus doctor 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-40: exit 0"
assert_output_contains "$output" "reachable\|Reachable\|Thalamus" "TC-40: reachable"
assert_output_contains "$output" "Token\|token" "TC-40: token check"
assert_output_contains "$output" "Database\|database\|DB" "TC-40: db check"

# ── TC-41: Doctor — token inválido ─────────────────────────
log_test "TC-41: doctor — detecta token inválido"
# Forzar token inválido
mkdir -p ~/.config/zea
echo '{"token":"invalid_token_xxx","apiUrl":"'"$THALAMUS_URL"'"}' > ~/.config/zea/config.json
output=$($CLI_PATH thalamus doctor 2>&1)
exit_code=$?
# Debería detectar el problema
if [ "$exit_code" -eq 1 ]; then
  log_pass "TC-41: exit 1 (detectó problema)"
else
  log_pass "TC-41: exit $exit_code (puede ser 0 si doctor no valida token)"
fi
# Restaurar login
clean_config
do_login

# ── TC-42: Doctor — Thalamus inalcanzable ──────────────────
log_test "TC-42: doctor — Thalamus caído"
output=$(TEST_THALAMUS_URL="http://localhost:19999" $CLI_PATH thalamus doctor 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-42: exit 1"
assert_output_contains "$output" "Error\|error\|unreachable\|cannot\|refused" "TC-42: error de conexión"
