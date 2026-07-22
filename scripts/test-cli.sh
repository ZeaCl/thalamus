#!/bin/bash
# test-cli.sh — E2E test runner for zea thalamus commands
#
# Runs test suites against a running Thalamus instance.
# Designed for ephemeral containers (docker compose up/down per run).
#
# Usage:
#   ./scripts/test-cli.sh                  # run all suites
#   ./scripts/test-cli.sh 02_auth          # run single suite
#   ./scripts/test-cli.sh 02_auth --verbose  # verbose mode
#
# Environment:
#   TEST_THALAMUS_URL  — Thalamus base URL (default: http://localhost:4100)
#   CLI_PATH           — Path to zea binary (default: zea)

set -euo pipefail

THALAMUS_URL="${TEST_THALAMUS_URL:-http://localhost:4100}"
CLI_PATH="${CLI_PATH:-zea}"
VERBOSE=false
PASS=0
FAIL=0
START_TIME=$(date +%s)

# ═══ Colors ══════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ═══ Helpers ═════════════════════════════════════════════
log_header() { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${NC}"; }
log_test()   { echo -e "  ${YELLOW}TEST${NC} $1"; }
log_pass()   { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS+1)); }
log_fail()   { echo -e "  ${RED}FAIL${NC} $1 — $2"; FAIL=$((FAIL+1)); }
log_info()   { echo -e "  ${CYAN}INFO${NC} $1"; }
log_debug()  { [ "$VERBOSE" = true ] && echo -e "  ${CYAN}DEBUG${NC} $1"; }

# ═══ Assertions ══════════════════════════════════════════

assert_exit_code() {
  local actual="$1" expected="$2" name="$3"
  if [ "$actual" -eq "$expected" ]; then
    log_pass "$name"
  else
    log_fail "$name" "expected exit $expected, got $actual"
  fi
}

assert_output_contains() {
  local output="$1" pattern="$2" name="$3"
  if echo "$output" | grep -qi "$pattern"; then
    log_pass "$name"
  else
    local preview=$(echo "$output" | head -3 | tr '\n' ' ')
    log_fail "$name" "expected output to contain '$pattern'. Got: $preview"
  fi
}

assert_output_not_contains() {
  local output="$1" pattern="$2" name="$3"
  if ! echo "$output" | grep -qi "$pattern"; then
    log_pass "$name"
  else
    log_fail "$name" "output should NOT contain '$pattern'"
  fi
}

assert_json_field() {
  local json="$1" field="$2" expected="$3" name="$4"
  local actual
  actual=$(echo "$json" | jq -r "$field" 2>/dev/null) || true
  if [ "$actual" = "$expected" ]; then
    log_pass "$name"
  else
    log_fail "$name" "expected $field='$expected', got '$actual'"
  fi
}

assert_json_field_contains() {
  local json="$1" field="$2" pattern="$3" name="$4"
  local actual
  actual=$(echo "$json" | jq -r "$field" 2>/dev/null) || true
  if echo "$actual" | grep -qi "$pattern"; then
    log_pass "$name"
  else
    log_fail "$name" "expected $field to contain '$pattern', got '$actual'"
  fi
}

# ═══ Wait for Thalamus ═══════════════════════════════════

wait_for_thalamus() {
  log_header "Waiting for Thalamus at $THALAMUS_URL"
  for i in $(seq 1 60); do
    local resp
    resp=$(curl -s -o /dev/null -w "%{http_code}" "$THALAMUS_URL/api/public/health" 2>/dev/null) || true
    if [ "$resp" = "200" ]; then
      echo -e "  ${GREEN}✅ Thalamus ready (took ${i}s)${NC}"
      return 0
    fi
    [ "$VERBOSE" = true ] && echo "  Waiting... ($i) got HTTP $resp"
    sleep 2
  done
  log_fail "bootstrap" "Thalamus did not start within 120s"
  exit 1
}

# ═══ Ensure clean config ═════════════════════════════════

backup_config() {
  local CONFIG_DIR="$HOME/.config/zea"
  if [ -f "$CONFIG_DIR/config.json" ]; then
    cp "$CONFIG_DIR/config.json" "$CONFIG_DIR/config.json.e2e-backup"
    log_info "Backed up existing CLI config"
  fi
}

restore_config() {
  local CONFIG_DIR="$HOME/.config/zea"
  if [ -f "$CONFIG_DIR/config.json.e2e-backup" ]; then
    mv "$CONFIG_DIR/config.json.e2e-backup" "$CONFIG_DIR/config.json"
    log_info "Restored original CLI config"
  else
    rm -f "$CONFIG_DIR/config.json"
  fi
}

clean_config() {
  rm -f "$HOME/.config/zea/config.json"
  log_info "Cleaned CLI config for fresh test"
}

# ═══ Run a suite ═════════════════════════════════════════

run_suite() {
  local suite_file="$1"
  local suite_name=$(basename "$suite_file" .sh)

  log_header "$suite_name"

  # Each suite starts with clean config
  clean_config

  # Source the suite (it has access to all assertion functions)
  source "$suite_file"

  local suite_pass=$(( PASS - suite_start_pass ))
}

# ═══ Main ════════════════════════════════════════════════

main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   ZEA CLI — E2E Test Runner         ║${NC}"
  echo -e "${BOLD}║   Target: $THALAMUS_URL${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"

  # Parse args
  for arg in "$@"; do
    case "$arg" in
      --verbose|-v) VERBOSE=true ;;
    esac
  done

  # Wait for Thalamus
  wait_for_thalamus
  backup_config

  # Determine which suites to run
  local suites=()
  if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
    suites=("test/cli/${1}.sh")
    if [ ! -f "${suites[0]}" ]; then
      echo -e "  ${RED}❌ Suite not found: test/cli/${1}.sh${NC}"
      exit 1
    fi
  else
    # Run all suites in order
    for f in test/cli/[0-9]*.sh; do
      [ -f "$f" ] && suites+=("$f")
    done
  fi

  if [ ${#suites[@]} -eq 0 ]; then
    echo -e "  ${RED}❌ No test suites found in test/cli/${NC}"
    exit 1
  fi

  # Run suites
  for suite in "${suites[@]}"; do
    suite_start_pass=$PASS
    source "$suite"
  done

  # Restore & report
  restore_config

  local elapsed=$(($(date +%s) - START_TIME))
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   Results (${elapsed}s)                   ║${NC}"
  echo -e "${BOLD}╠══════════════════════════════════════╣${NC}"
  echo -e "${BOLD}║   ${GREEN}PASS: $PASS${NC}${BOLD}                          ║${NC}"
  echo -e "${BOLD}║   ${RED}FAIL: $FAIL${NC}${BOLD}                          ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"

  if [ "$FAIL" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
