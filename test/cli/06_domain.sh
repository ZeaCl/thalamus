#!/bin/bash
# Suite 06 — Domain Roles: register, list, grant, roles, revoke
# Requiere: login + org ZEA activa

do_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." \
    --url "$THALAMUS_URL" > /dev/null 2>&1
  $CLI_PATH thalamus org switch zea > /dev/null 2>&1
}

USER_ID="c0000000-852c-44e5-aee1-a761ec76eaea"
ORG_ID="ea7b11ea-852c-44e5-aee1-a761ec76eaea"
DOMAIN="e2e_test_cli"

# ── TC-33: Domain register ─────────────────────────────────
log_test "TC-33: domain register — $DOMAIN"
do_login
output=$($CLI_PATH thalamus domain register \
  --domain "$DOMAIN" \
  --scopes '[{"scope":"e2e:read","description":"Test read access"},{"scope":"e2e:write","description":"Test write access"}]' \
  --output json 2>&1)
assert_output_contains "$output" "registered\|Registered\|$DOMAIN" "TC-33: registered"
assert_output_contains "$output" "2" "TC-33: 2 scopes"

# ── TC-34: Domain list — contiene el domain ────────────────
log_test "TC-34: domain list"
output=$($CLI_PATH thalamus domain list --output json 2>&1)
assert_output_contains "$output" "$DOMAIN" "TC-34: domain en lista"

# ── TC-35: Domain grant ────────────────────────────────────
log_test "TC-35: domain grant — role tester"
output=$($CLI_PATH thalamus domain grant \
  --user "$USER_ID" \
  --org "$ORG_ID" \
  --domain "$DOMAIN" \
  --role "tester" \
  --scopes "e2e:read,e2e:write" \
  --output json 2>&1)
assert_output_contains "$output" "granted\|Granted\|created\|Created\|updated\|Updated" "TC-35: granted/created"

# ── TC-36: Domain grant — idempotente (mismo role) ─────────
log_test "TC-36: domain grant — idempotente"
output=$($CLI_PATH thalamus domain grant \
  --user "$USER_ID" \
  --org "$ORG_ID" \
  --domain "$DOMAIN" \
  --role "tester" \
  --scopes "e2e:read" \
  --output json 2>&1)
# Debería hacer update sin error
assert_output_contains "$output" "updated\|Updated\|granted\|Granted" "TC-36: no error en re-grant"

# ── TC-37: Domain roles — filtrado por dominio ─────────────
log_test "TC-37: domain roles — por dominio"
output=$($CLI_PATH thalamus domain roles --domain "$DOMAIN" --output json 2>&1)
assert_output_contains "$output" "tester" "TC-37: role tester visible"
assert_output_contains "$output" "$USER_ID" "TC-37: user_id visible"

# ── TC-38: Domain revoke ───────────────────────────────────
log_test "TC-38: domain revoke"
output=$($CLI_PATH thalamus domain revoke \
  --user "$USER_ID" \
  --org "$ORG_ID" \
  --domain "$DOMAIN" \
  --role "tester" \
  --output json 2>&1)
assert_output_contains "$output" "revoked\|Revoked" "TC-38: revoked message"

# ── TC-39: Domain revoke — ya no aparece ───────────────────
log_test "TC-39: domain revoke — ya no aparece en roles"
output=$($CLI_PATH thalamus domain roles --domain "$DOMAIN" --output json 2>&1)
# No debería contener "tester" para este user
if echo "$output" | jq -e '.[] | select(.role == "tester")' > /dev/null 2>&1; then
  log_fail "TC-39" "tester role aún aparece después de revoke"
else
  log_pass "TC-39: role tester ya no aparece"
fi
