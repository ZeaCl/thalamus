#!/bin/bash
# smoke-test-cli.sh — Quick CLI smoke test with ephemeral Thalamus
#
# Runs the most critical CLI tests against a fresh Thalamus container.
# Designed to run before git push — catches regressions in < 2 minutes.
#
# Usage:
#   ./scripts/smoke-test-cli.sh           # full smoke
#   ./scripts/smoke-test-cli.sh --quick   # health + auth only (30s)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

QUICK=false
[[ "${1:-}" == "--quick" ]] && QUICK=true

echo -e "${CYAN}═══ CLI Smoke Test ═══${NC}"
echo ""

# ═══ Start ephemeral Thalamus ═══════════════════════════
echo -e "${CYAN}── Starting ephemeral Thalamus ──${NC}"
docker compose -f docker-compose.test.yml down -v 2>/dev/null || true
docker compose -f docker-compose.test.yml up -d --wait 2>&1 | tail -3

# ═══ Run critical suites ═════════════════════════════════
echo ""
echo -e "${CYAN}── Health + Auth ──${NC}"
./scripts/test-cli.sh 01_health --verbose || {
  echo -e "${RED}❌ Health check failed${NC}"
  docker compose -f docker-compose.test.yml down -v
  exit 1
}

./scripts/test-cli.sh 02_auth --verbose || {
  echo -e "${RED}❌ Auth check failed${NC}"
  docker compose -f docker-compose.test.yml down -v
  exit 1
}

if [ "$QUICK" = false ]; then
  echo ""
  echo -e "${CYAN}── Org + Token + Client ──${NC}"
  ./scripts/test-cli.sh 03_org --verbose || {
    echo -e "${RED}❌ Org check failed${NC}"
    docker compose -f docker-compose.test.yml down -v
    exit 1
  }

  ./scripts/test-cli.sh 05_token --verbose || {
    echo -e "${RED}❌ Token check failed${NC}"
    docker compose -f docker-compose.test.yml down -v
    exit 1
  }

  ./scripts/test-cli.sh 04_client --verbose || {
    echo -e "${RED}❌ Client check failed${NC}"
    docker compose -f docker-compose.test.yml down -v
    exit 1
  }
fi

# ═══ Teardown ══════════════════════════════════════════
docker compose -f docker-compose.test.yml down -v 2>/dev/null

echo ""
echo -e "${GREEN}✅ CLI Smoke Test passed${NC}"
