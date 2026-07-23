#!/bin/bash
# Suite 01 — Health + OIDC Discovery
# Test: zea thalamus health, oidc discovery, oidc jwks
# No auth required.

# ── TC-01: Health — JSON ──────────────────────────────────
log_test "TC-01: health — JSON output OK"
output=$($CLI_PATH thalamus health --output json 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-01: exit 0"
assert_json_field "$output" '.status' '"ok"' "TC-01: status ok"
assert_json_field "$output" '.checks.database' '"ok"' "TC-01: db ok"
assert_json_field "$output" '.checks.cache' '"ok"' "TC-01: cache ok"

# ── TC-02: Health — Table ─────────────────────────────────
log_test "TC-02: health — table output"
output=$($CLI_PATH thalamus health 2>&1)
assert_output_contains "$output" "HEALTHY\|ok" "TC-02: shows HEALTHY or ok"
assert_output_contains "$output" "Database\|database" "TC-02: shows Database check"

# ── TC-03: OIDC Discovery ─────────────────────────────────
log_test "TC-03: oidc discovery"
output=$($CLI_PATH thalamus oidc discovery --output json 2>&1)
assert_json_field_contains "$output" '.issuer' "$THALAMUS_URL" "TC-03: issuer correcto"
assert_json_field_contains "$output" '.token_endpoint' '/oauth/token' "TC-03: token endpoint"
# Verificar que tiene scopes
scope_count=$(echo "$output" | jq '.scopes_supported | length' 2>/dev/null)
if [ "$scope_count" -gt 0 ]; then
  log_pass "TC-03: tiene scopes ($scope_count)"
else
  log_fail "TC-03" "scopes_supported está vacío"
fi

# ── TC-04: OIDC JWKS ──────────────────────────────────────
log_test "TC-04: oidc jwks"
output=$($CLI_PATH thalamus oidc jwks --output json 2>&1)
key_count=$(echo "$output" | jq '.keys | length' 2>/dev/null)
if [ "$key_count" -gt 0 ]; then
  log_pass "TC-04: tiene keys ($key_count)"
else
  log_fail "TC-04" "keys está vacío"
fi
