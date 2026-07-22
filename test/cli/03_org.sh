#!/bin/bash
# Suite 03 — Organizaciones: list, show, switch, member
# Requiere: login previo

do_login() {
  $CLI_PATH thalamus auth login --email admin@zea.local --password "Admin123!" \
    --url "$THALAMUS_URL" > /dev/null 2>&1
}

# ── TC-13: Org list — 2+ organizaciones ────────────────────
log_test "TC-13: org list — user en 2 orgs"
do_login
output=$($CLI_PATH thalamus org list --output json 2>&1)
org_count=$(echo "$output" | jq 'length' 2>/dev/null || echo "0")
if [ "$org_count" -ge 2 ]; then
  log_pass "TC-13: $org_count organizaciones (>=2)"
else
  log_fail "TC-13" "expected >=2 orgs, got $org_count"
fi

# ── TC-14: Org list — formato table ────────────────────────
log_test "TC-14: org list — table output"
output=$($CLI_PATH thalamus org list 2>&1)
assert_output_contains "$output" "ZEA" "TC-14: muestra ZEA"
assert_output_contains "$output" "Südlich\|Sudlich" "TC-14: muestra Südlich"

# ── TC-15: Org show — detalle ──────────────────────────────
log_test "TC-15: org show — detalle de ZEA"
output=$($CLI_PATH thalamus org show zea --output json 2>&1)
assert_json_field "$output" '.name' '"ZEA"' "TC-15: nombre ZEA"
assert_json_field "$output" '.plan_type' '"enterprise"' "TC-15: plan enterprise"

# ── TC-16: Org show — no existe ────────────────────────────
log_test "TC-16: org show — organización inexistente"
output=$($CLI_PATH thalamus org show noexiste --output json 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-16: exit 1"
assert_output_contains "$output" "not found\|Not found\|no existe" "TC-16: error not found"

# ── TC-17: Org switch ──────────────────────────────────────
log_test "TC-17: org switch — cambiar a Südlich"
output=$($CLI_PATH thalamus org switch sudlich 2>&1)
assert_output_contains "$output" "Südlich\|Sudlich\|switched\|Switched\|Active" "TC-17: switched"
# Verificar whoami refleja el cambio
output=$($CLI_PATH thalamus auth whoami 2>&1)
assert_output_contains "$output" "Südlich\|Sudlich" "TC-17: whoami muestra Südlich"

# Volver a ZEA para el resto de tests
$CLI_PATH thalamus org switch zea > /dev/null 2>&1

# ── TC-18: Org member list ─────────────────────────────────
log_test "TC-18: org member list — miembros de Südlich"
output=$($CLI_PATH thalamus org member list sudlich --output json 2>&1)
member_count=$(echo "$output" | jq 'length' 2>/dev/null || echo "0")
if [ "$member_count" -ge 2 ]; then
  log_pass "TC-18: $member_count miembros (>=2)"
else
  log_fail "TC-18" "expected >=2 miembros, got $member_count"
fi
