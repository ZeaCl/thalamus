# ZEA CLI — Matriz de Testing End-to-End

> **Status**: Draft v0.1
> **Última actualización**: 2025-07-21

---

## Estrategia de testing

Cada comando de `zea thalamus` se prueba contra una instancia **real y efímera** de Thalamus.
El contenedor se crea, se ejecutan seeds, se corre el test, y se destruye — sin dejar rastro.

Esto garantiza que:
- Los tests validan la integración completa (CLI → HTTP → Thalamus → DB)
- Son reproducibles en cualquier máquina (desarrollo local, CI)
- No dependen de un Thalamus "de staging" compartido (evita flaky tests)
- Pueden ejecutarse en paralelo (cada contenedor en su propio puerto)

### Inspiración

Mismo patrón que usamos para testear microservicios (fm_funds, fm_investors):

```bash
# El contenedor vive solo durante el test
docker compose -f docker-compose.test.yml up -d --wait
./scripts/test-cli.sh "auth login"
docker compose -f docker-compose.test.yml down -v
```

---

## Infraestructura de test

### `docker-compose.test.yml`

```yaml
# docker-compose.test.yml — Contenedor efímero para tests E2E de CLI
# Uso: docker compose -f docker-compose.test.yml up -d --wait && ./scripts/test-cli.sh

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: thalamus_test
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "${TEST_DB_PORT:-5533}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 3s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    command: redis-server --requirepass redis_password
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "redis_password", "ping"]
      interval: 3s
      timeout: 3s
      retries: 10

  thalamus:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      DATABASE_URL: ecto://postgres:postgres@postgres/thalamus_test
      REDIS_URL: redis://:redis_password@redis:6379
      SECRET_KEY_BASE: "test_secret_key_base_min_64_chars_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      PHX_HOST: localhost
      PORT: 4000
      MIX_ENV: prod
      TEST_AUTH_ALLOWED: "true"
      SEED_ON_START: "true"
    ports:
      - "${TEST_PORT:-4000}:4000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/api/public/health"]
      interval: 3s
      timeout: 3s
      retries: 30
```

### `scripts/test-cli.sh`

```bash
#!/bin/bash
# test-cli.sh — Runner de tests E2E para zea thalamus
# Uso: ./scripts/test-cli.sh [test_name] [--verbose]

set -e

THALAMUS_URL="${TEST_THALAMUS_URL:-http://localhost:4000}"
CLI_PATH="${CLI_PATH:-zea}"  # zea binario global o node src/index.js
VERBOSE=false
PASS=0
FAIL=0

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_test() { echo -e "  ${YELLOW}TEST${NC} $1"; }
log_pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS+1)); }
log_fail() { echo -e "  ${RED}FAIL${NC} $1 — $2"; FAIL=$((FAIL+1)); }

assert_output_contains() {
  local output="$1" pattern="$2" test_name="$3"
  if echo "$output" | grep -q "$pattern"; then
    log_pass "$test_name"
  else
    log_fail "$test_name" "expected output to contain '$pattern'. Got: $(echo "$output" | head -1)"
  fi
}

assert_exit_code() {
  local exit_code="$1" expected="$2" test_name="$3"
  if [ "$exit_code" -eq "$expected" ]; then
    log_pass "$test_name"
  else
    log_fail "$test_name" "expected exit $expected, got $exit_code"
  fi
}

assert_json_field() {
  local json="$1" field="$2" expected="$3" test_name="$4"
  local actual=$(echo "$json" | jq -r "$field" 2>/dev/null)
  if [ "$actual" = "$expected" ]; then
    log_pass "$test_name"
  else
    log_fail "$test_name" "expected $field='$expected', got '$actual'"
  fi
}

# ─── Wait for Thalamus ────────────────────────────────────
wait_for_thalamus() {
  echo "Waiting for Thalamus at $THALAMUS_URL..."
  for i in $(seq 1 30); do
    if curl -s "$THALAMUS_URL/api/public/health" | grep -q '"status":"ok"'; then
      echo "✅ Thalamus ready"
      return 0
    fi
    sleep 2
  done
  echo "❌ Thalamus did not start in time"
  exit 1
}

# ─── Run a single test file ──────────────────────────────
run_test() {
  local test_file="$1"
  echo ""
  echo "═══ $(basename $test_file) ═══"
  source "$test_file"
}

# ─── Main ─────────────────────────────────────────────────
main() {
  wait_for_thalamus

  if [ -n "$1" ]; then
    run_test "test/cli/$1.sh"
  else
    for test_file in test/cli/[0-9]*.sh; do
      run_test "$test_file"
    done
  fi

  echo ""
  echo "═══ Results ═══"
  echo -e "  ${GREEN}PASS: $PASS${NC}"
  echo -e "  ${RED}FAIL: $FAIL${NC}"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
```

---

## Matriz de tests

Cada archivo en `test/cli/` cubre un grupo de comandos. El formato es `NN_nombre.sh`
donde NN controla el orden de ejecución (importante: auth antes que el resto).

### `test/cli/01_health.sh` — Health + Discovery

```bash
#!/bin/bash
# Test: health, oidc discovery, oidc jwks

# ── TC-01: Health OK ──────────────────────────────────────
log_test "TC-01: health — Thalamus healthy"
output=$($CLI_PATH thalamus health --output json 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-01: exit code 0"
assert_json_field "$output" '.status' '"ok"' "TC-01: status ok"
assert_json_field "$output" '.checks.database' '"ok"' "TC-01: db ok"
assert_json_field "$output" '.checks.cache' '"ok"' "TC-01: cache ok"

# ── TC-02: Health — formato table ─────────────────────────
log_test "TC-02: health — table output"
output=$($CLI_PATH thalamus health 2>&1)
assert_output_contains "$output" "HEALTHY" "TC-02: shows HEALTHY"
assert_output_contains "$output" "Database" "TC-02: shows Database check"
assert_output_contains "$output" "Cache" "TC-02: shows Cache check"

# ── TC-03: OIDC Discovery ─────────────────────────────────
log_test "TC-03: oidc discovery"
output=$($CLI_PATH thalamus oidc discovery --output json 2>&1)
assert_json_field "$output" '.issuer' "\"$THALAMUS_URL\"" "TC-03: issuer correcto"
assert_json_field "$output" '.token_endpoint' "\"$THALAMUS_URL/oauth/token\"" "TC-03: token endpoint"
assert_json_field "$output" '.scopes_supported | length > 0' 'true' "TC-03: tiene scopes"

# ── TC-04: OIDC JWKS ──────────────────────────────────────
log_test "TC-04: oidc jwks"
output=$($CLI_PATH thalamus oidc jwks --output json 2>&1)
assert_json_field "$output" '.keys | length > 0' 'true' "TC-04: tiene keys"
```

### `test/cli/02_auth.sh` — Login, Whoami, Logout, Debug

```bash
#!/bin/bash
# Test: auth login (direct), whoami, logout, debug
# Requiere: seeds ejecutados con c@zea.cl / GusVicentAnto1.

# ── TC-05: Direct login — credenciales válidas ─────────────
log_test "TC-05: auth login directo — credenciales válidas"
output=$($CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-05: exit code 0"
assert_output_contains "$output" "Successfully authenticated" "TC-05: authenticated message"
assert_output_contains "$output" "c@zea.cl" "TC-05: shows user email"
assert_output_contains "$output" "ZEA" "TC-05: shows organization"

# ── TC-06: Direct login — credenciales inválidas ───────────
log_test "TC-06: auth login directo — password inválida"
output=$($CLI_PATH thalamus auth login --email c@zea.cl --password "wrong" 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-06: exit code 1"
assert_output_contains "$output" "Invalid email or password" "TC-06: error message"

# ── TC-07: Direct login — email no existe ──────────────────
log_test "TC-07: auth login directo — email no existe"
output=$($CLI_PATH thalamus auth login --email noexiste@test.com --password "x" 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-07: exit code 1"
assert_output_contains "$output" "Invalid" "TC-07: error message"

# ── TC-08: Whoami — token válido ───────────────────────────
log_test "TC-08: whoami — después de login exitoso"
output=$($CLI_PATH thalamus auth whoami 2>&1)
assert_output_contains "$output" "c@zea.cl" "TC-08: email visible"
assert_output_contains "$output" "ZEA" "TC-08: org visible"
assert_output_contains "$output" "owner" "TC-08: role visible"

# ── TC-09: Whoami — sin token ──────────────────────────────
log_test "TC-09: whoami — sin token guardado"
# Borrar config temporalmente
mv ~/.config/zea/config.json ~/.config/zea/config.json.bak 2>/dev/null || true
output=$($CLI_PATH thalamus auth whoami 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-09: exit code 1"
assert_output_contains "$output" "Not authenticated" "TC-09: error message"
# Restaurar
mv ~/.config/zea/config.json.bak ~/.config/zea/config.json 2>/dev/null || true

# ── TC-10: Auth debug — JWT decode ─────────────────────────
log_test "TC-10: auth debug — decodifica JWT"
token=$(cat ~/.config/zea/config.json | jq -r '.token')
output=$($CLI_PATH thalamus auth debug "$token" --output json 2>&1)
assert_json_field "$output" '.payload.email' '"c@zea.cl"' "TC-10: email en payload"
assert_json_field "$output" '.payload.sub | length > 0' 'true' "TC-10: sub presente"
assert_json_field "$output" '.server_status.active' 'true' "TC-10: token activo en servidor"

# ── TC-11: Logout ──────────────────────────────────────────
log_test "TC-11: auth logout"
output=$($CLI_PATH thalamus auth logout 2>&1)
assert_output_contains "$output" "Logged out" "TC-11: logout message"
# Verificar que whoami falla después de logout
output=$($CLI_PATH thalamus auth whoami 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-11: whoami fails after logout"
```

### `test/cli/03_org.sh` — Organizaciones

```bash
#!/bin/bash
# Test: org list, show, switch, member
# Requiere: auth previo (login antes de correr este test)

# ═══ Setup: login ═══════════════════════════════════════
setup_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." > /dev/null 2>&1
}

# ── TC-12: Org list — 2+ organizaciones ────────────────────
log_test "TC-12: org list — user en 2 orgs"
setup_login
output=$($CLI_PATH thalamus org list --output json 2>&1)
assert_json_field "$output" 'length' '2' "TC-12: 2 organizaciones"
assert_json_field "$output" '.[0].name' '"ZEA"' "TC-12: primera org es ZEA"

# ── TC-13: Org list — formato table ────────────────────────
log_test "TC-13: org list — table output"
output=$($CLI_PATH thalamus org list 2>&1)
assert_output_contains "$output" "ZEA" "TC-13: muestra ZEA"
assert_output_contains "$output" "Südlich" "TC-13: muestra Südlich"

# ── TC-14: Org show ────────────────────────────────────────
log_test "TC-14: org show — detalle de ZEA"
output=$($CLI_PATH thalamus org show zea --output json 2>&1)
assert_json_field "$output" '.name' '"ZEA"' "TC-14: nombre ZEA"
assert_json_field "$output" '.plan_type' '"enterprise"' "TC-14: plan enterprise"

# ── TC-15: Org switch ──────────────────────────────────────
log_test "TC-15: org switch — cambiar a Südlich"
output=$($CLI_PATH thalamus org switch sudlich 2>&1)
assert_output_contains "$output" "Südlich" "TC-15: switched to Südlich"
# Verificar que whoami refleja el cambio
output=$($CLI_PATH thalamus auth whoami 2>&1)
assert_output_contains "$output" "Südlich" "TC-15: whoami muestra Südlich como activa"

# ── TC-16: Org member list ─────────────────────────────────
log_test "TC-16: org member list — miembros de Südlich"
output=$($CLI_PATH thalamus org member list sudlich --output json 2>&1)
count=$(echo "$output" | jq 'length')
[ "$count" -ge 2 ] && log_pass "TC-16: 2+ miembros" || log_fail "TC-16: expected >=2, got $count"
assert_output_contains "$output" "ccerda@sudlich.cl" "TC-16: ccerda en miembros"
assert_output_contains "$output" "c@zea.cl" "TC-16: c@zea.cl cross-org en miembros"
```

### `test/cli/04_client.sh` — OAuth2 Clients

```bash
#!/bin/bash
# Test: client create, list, show, validate, rotate-secret, delete
# Requiere: auth previo

setup_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." > /dev/null 2>&1
  $CLI_PATH thalamus org switch zea > /dev/null 2>&1
}

# ── TC-17: Client create — confidential ────────────────────
log_test "TC-17: client create — confidential"
setup_login
output=$($CLI_PATH thalamus client create \
  --name "E2E Test Client" \
  --type confidential \
  --redirect-uris "http://localhost:9999/callback" \
  --grants "authorization_code,refresh_token" \
  --scopes "openid,profile,email" \
  --output json 2>&1)
assert_exit_code $? 0 "TC-17: exit 0"
assert_json_field "$output" '.data.name' '"E2E Test Client"' "TC-17: nombre guardado"
assert_json_field "$output" '.data.client_type' '"confidential"' "TC-17: tipo confidential"
# Guardar client_id para tests siguientes
CLIENT_ID=$(echo "$output" | jq -r '.data.id')
CLIENT_SECRET=$(echo "$output" | jq -r '.data.client_secret')
[ -n "$CLIENT_SECRET" ] && log_pass "TC-17: secret generado" || log_fail "TC-17: sin secret"

# ── TC-18: Client list ─────────────────────────────────────
log_test "TC-18: client list"
output=$($CLI_PATH thalamus client list --output json 2>&1)
assert_output_contains "$output" "E2E Test Client" "TC-18: aparece en lista"

# ── TC-19: Client show ─────────────────────────────────────
log_test "TC-19: client show"
output=$($CLI_PATH thalamus client show "$CLIENT_ID" --output json 2>&1)
assert_json_field "$output" '.data.redirect_uris[0]' '"http://localhost:9999/callback"' "TC-19: redirect uri"

# ── TC-20: Client validate — OK ────────────────────────────
log_test "TC-20: client validate — OK"
output=$($CLI_PATH thalamus client validate "$CLIENT_ID" --output json 2>&1)
assert_json_field "$output" '.status' '"pass"' "TC-20: overall pass"

# ── TC-21: Client rotate-secret ────────────────────────────
log_test "TC-21: client rotate-secret"
output=$($CLI_PATH thalamus client rotate-secret "$CLIENT_ID" --output json 2>&1)
NEW_SECRET=$(echo "$output" | jq -r '.data.client_secret')
[ "$NEW_SECRET" != "$CLIENT_SECRET" ] && log_pass "TC-21: secret rotado (diferente)" || log_fail "TC-21: mismo secret"

# ── TC-22: Client create — redirect URI inválida ───────────
log_test "TC-22: client create — URI inválida"
output=$($CLI_PATH thalamus client create \
  --name "Invalid Client" \
  --redirect-uris "not-a-uri" \
  --output json 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-22: exit 1"
assert_output_contains "$output" "Invalid redirect URI" "TC-22: error message"

# ── TC-23: Client delete ───────────────────────────────────
log_test "TC-23: client delete"
output=$(echo "y" | $CLI_PATH thalamus client delete "$CLIENT_ID" 2>&1)
assert_output_contains "$output" "deleted\|deactivated\|Deleted" "TC-23: confirmación delete"
```

### `test/cli/05_token.sh` — Personal Access Tokens

```bash
#!/bin/bash
# Test: token create, list, revoke

setup_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." > /dev/null 2>&1
  $CLI_PATH thalamus org switch zea > /dev/null 2>&1
}

# ── TC-24: Token create ────────────────────────────────────
log_test "TC-24: token create"
setup_login
output=$($CLI_PATH thalamus token create --name "E2E Test Token" --output json 2>&1)
assert_json_field "$output" '.data.name' '"E2E Test Token"' "TC-24: nombre"
TOKEN_VALUE=$(echo "$output" | jq -r '.token')
[ "${#TOKEN_VALUE}" -gt 20 ] && log_pass "TC-24: token generado ($TOKEN_VALUE)" || log_fail "TC-24: token corto"
TOKEN_ID=$(echo "$output" | jq -r '.data.id')

# ── TC-25: Token list ──────────────────────────────────────
log_test "TC-25: token list"
output=$($CLI_PATH thalamus token list --output json 2>&1)
assert_output_contains "$output" "E2E Test Token" "TC-25: token en lista"

# ── TC-26: Usar PAT como auth ──────────────────────────────
log_test "TC-26: usar PAT como ZEA_PAT"
ZEA_PAT="$TOKEN_VALUE" $CLI_PATH thalamus auth whoami --output json 2>&1 > /dev/null
assert_exit_code $? 0 "TC-26: whoami con PAT funciona"

# ── TC-27: Token revoke ────────────────────────────────────
log_test "TC-27: token revoke"
output=$($CLI_PATH thalamus token revoke "$TOKEN_ID" 2>&1)
assert_output_contains "$output" "revoked" "TC-27: revoked message"
# Verificar que ya no aparece en lista
output=$($CLI_PATH thalamus token list --output json 2>&1)
! echo "$output" | grep -q "E2E Test Token" && log_pass "TC-27: token ya no aparece" || log_fail "TC-27: token sigue en lista"
```

### `test/cli/06_domain.sh` — Domain Roles

```bash
#!/bin/bash
# Test: domain register, grant, revoke, roles

setup_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." > /dev/null 2>&1
  $CLI_PATH thalamus org switch zea > /dev/null 2>&1
}

# ── TC-28: Domain register ─────────────────────────────────
log_test "TC-28: domain register"
setup_login
output=$($CLI_PATH thalamus domain register \
  --domain "e2e_test" \
  --scopes '[{"scope":"e2e:read","description":"Test read"},{"scope":"e2e:write","description":"Test write"}]' \
  --output json 2>&1)
assert_output_contains "$output" "registered" "TC-28: registered message"
assert_output_contains "$output" "2 scopes" "TC-28: 2 scopes"

# ── TC-29: Domain list ─────────────────────────────────────
log_test "TC-29: domain list"
output=$($CLI_PATH thalamus domain list --output json 2>&1)
assert_output_contains "$output" "e2e_test" "TC-29: domain en lista"

# ── TC-30: Domain grant ────────────────────────────────────
log_test "TC-30: domain grant"
output=$($CLI_PATH thalamus domain grant \
  --user "c0000000-852c-44e5-aee1-a761ec76eaea" \
  --org "ea7b11ea-852c-44e5-aee1-a761ec76eaea" \
  --domain "e2e_test" \
  --role "tester" \
  --scopes "e2e:read,e2e:write" \
  --output json 2>&1)
assert_output_contains "$output" "granted" "TC-30: granted message"

# ── TC-31: Domain roles — filtrado ─────────────────────────
log_test "TC-31: domain roles — por dominio"
output=$($CLI_PATH thalamus domain roles --domain "e2e_test" --output json 2>&1)
assert_output_contains "$output" "tester" "TC-31: role tester visible"

# ── TC-32: Domain revoke ───────────────────────────────────
log_test "TC-32: domain revoke"
output=$($CLI_PATH thalamus domain revoke \
  --user "c0000000-852c-44e5-aee1-a761ec76eaea" \
  --org "ea7b11ea-852c-44e5-aee1-a761ec76eaea" \
  --domain "e2e_test" \
  --role "tester" \
  --output json 2>&1)
assert_output_contains "$output" "revoked" "TC-32: revoked message"
```

### `test/cli/07_doctor.sh` — Diagnóstico

```bash
#!/bin/bash
# Test: doctor — diagnóstico completo

setup_login() {
  $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." > /dev/null 2>&1
}

# ── TC-33: Doctor — todo OK ────────────────────────────────
log_test "TC-33: doctor — diagnóstico completo OK"
setup_login
output=$($CLI_PATH thalamus doctor 2>&1)
exit_code=$?
assert_exit_code $exit_code 0 "TC-33: exit 0"
assert_output_contains "$output" "Thalamus reachable" "TC-33: reachable"
assert_output_contains "$output" "Token" "TC-33: token check"
assert_output_contains "$output" "Database" "TC-33: db check"

# ── TC-34: Doctor — token expirado (simulado) ──────────────
log_test "TC-34: doctor — detecta token inválido"
# Forzar un token inválido en config
echo '{"token":"invalid_token_xxx"}' > ~/.config/zea/config.json
output=$($CLI_PATH thalamus doctor 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-34: exit 1"
assert_output_contains "$output" "Token" "TC-34: detecta problema de token"
# Restaurar
setup_login
```

### `test/cli/08_errors.sh` — Manejo de errores

```bash
#!/bin/bash
# Test: errores de red, 401, 403, 404, timeouts

# ── TC-35: Thalamus inalcanzable ───────────────────────────
log_test "TC-35: error — Thalamus caído"
# Apuntar a un puerto donde no hay nada
THALAMUS_URL="http://localhost:19999" $CLI_PATH thalamus health 2>&1 > /dev/null
exit_code=$?
assert_exit_code $exit_code 1 "TC-35: exit 1 (network error)"

# ── TC-36: Endpoint no autorizado sin token ────────────────
log_test "TC-36: error — 401 sin token"
# Borrar config
mv ~/.config/zea/config.json ~/.config/zea/config.json.bak 2>/dev/null || true
output=$(ZEA_PAT="invalid" $CLI_PATH thalamus org list 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-36: exit 1"
assert_output_contains "$output" "authenticate\|unauthorized\|token\|login" "TC-36: sugiere autenticarse"
mv ~/.config/zea/config.json.bak ~/.config/zea/config.json 2>/dev/null || true

# ── TC-37: Recurso no encontrado ───────────────────────────
log_test "TC-37: error — 404 not found"
output=$($CLI_PATH thalamus user show "00000000-0000-0000-0000-000000000000" 2>&1)
exit_code=$?
assert_exit_code $exit_code 1 "TC-37: exit 1"
assert_output_contains "$output" "not found" "TC-37: not found message"

# ── TC-38: Dry-run no ejecuta ──────────────────────────────
log_test "TC-38: dry-run — no ejecuta"
setup_login() { $CLI_PATH thalamus auth login --email c@zea.cl --password "GusVicentAnto1." > /dev/null 2>&1; }
setup_login
output=$($CLI_PATH thalamus client create --name "DryRunTest" --dry-run 2>&1)
assert_exit_code $? 0 "TC-38: exit 0 (dry-run no falla)"
assert_output_contains "$output" "DRY RUN" "TC-38: indica dry run"
# Verificar que el client NO fue creado
output=$($CLI_PATH thalamus client list --output json 2>&1)
! echo "$output" | grep -q "DryRunTest" && log_pass "TC-38: client no fue creado" || log_fail "TC-38: client fue creado!"
```

---

## GitHub Actions Workflow

### `.github/workflows/cli-e2e.yml`

```yaml
name: CLI E2E Tests

on:
  push:
    branches: [main, develop]
    paths:
      - 'lib/**'
      - 'priv/**'
      - 'docs/cli/**'
      - 'test/cli/**'
      - 'scripts/test-cli.sh'
      - 'docker-compose.test.yml'
  pull_request:
    branches: [main, develop]
    paths:
      - 'lib/**'
      - 'priv/**'
      - 'docs/cli/**'
      - 'test/cli/**'
      - 'scripts/test-cli.sh'
      - 'docker-compose.test.yml'

jobs:
  cli-e2e:
    name: CLI E2E (${{ matrix.test-suite }})
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        test-suite:
          - "01_health"
          - "02_auth"
          - "03_org"
          - "04_client"
          - "05_token"
          - "06_domain"
          - "07_doctor"
          - "08_errors"

    steps:
      - name: Checkout thalamus
        uses: actions/checkout@v4

      - name: Checkout zea-cli
        uses: actions/checkout@v4
        with:
          repository: ZeaCl/zea-cli
          path: zea-cli

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install zea-cli
        working-directory: zea-cli
        run: npm install && npm link

      - name: Build Thalamus Docker image
        run: docker compose -f docker-compose.test.yml build thalamus

      - name: Start ephemeral Thalamus
        run: |
          docker compose -f docker-compose.test.yml up -d --wait
          # Wait for seeds to complete
          sleep 5

      - name: Run test suite
        run: ./scripts/test-cli.sh ${{ matrix.test-suite }} --verbose
        env:
          TEST_THALAMUS_URL: http://localhost:4000
          CLI_PATH: zea

      - name: Debug — Thalamus logs
        if: failure()
        run: docker compose -f docker-compose.test.yml logs thalamus

      - name: Debug — DB state
        if: failure()
        run: |
          docker compose -f docker-compose.test.yml exec -T postgres \
            psql -U postgres -d thalamus_test -c "\dt"
          docker compose -f docker-compose.test.yml exec -T postgres \
            psql -U postgres -d thalamus_test -c "SELECT id, email, name FROM users;"

      - name: Teardown
        if: always()
        run: docker compose -f docker-compose.test.yml down -v
```

---

## Matriz resumen: 38 casos de prueba

| Suite | # Tests | Comandos cubiertos |
|---|---|---|
| `01_health` | TC-01 a TC-04 | `health`, `oidc discovery`, `oidc jwks` |
| `02_auth` | TC-05 a TC-11 | `auth login`, `whoami`, `logout`, `debug` |
| `03_org` | TC-12 a TC-16 | `org list`, `show`, `switch`, `member list` |
| `04_client` | TC-17 a TC-23 | `client create`, `list`, `show`, `validate`, `rotate-secret`, `delete` |
| `05_token` | TC-24 a TC-27 | `token create`, `list`, `revoke` + PAT como auth |
| `06_domain` | TC-28 a TC-32 | `domain register`, `list`, `grant`, `roles`, `revoke` |
| `07_doctor` | TC-33 a TC-34 | `doctor` (OK + token inválido) |
| `08_errors` | TC-35 a TC-38 | Errores de red, 401, 404, dry-run |

### Matriz de cobertura de assertions

Cada test valida al menos 3 cosas:

| Tipo de assertion | Ejemplo |
|---|---|
| `assert_exit_code` | `exit 0` para éxito, `exit 1` para error |
| `assert_output_contains` | El output contiene una string esperada |
| `assert_json_field` | Un campo JSON tiene el valor esperado (usando `jq`) |
| `assert_not_contains` | El output NO contiene cierta string (ej: dry-run no crea) |

---

## Ejecución local

```bash
# 1. Levantar contenedor efímero
TEST_PORT=4000 docker compose -f docker-compose.test.yml up -d --wait

# 2. Correr todos los tests
TEST_THALAMUS_URL=http://localhost:4000 ./scripts/test-cli.sh

# 3. Correr una suite específica
./scripts/test-cli.sh 02_auth

# 4. Modo verbose (muestra request/response)
./scripts/test-cli.sh 04_client --verbose

# 5. Tear down (siempre, incluso si tests fallan)
docker compose -f docker-compose.test.yml down -v
```

---

## Principios

1. **Efímero**: cada run crea y destruye el contenedor. No hay estado entre runs.
2. **Aislado**: los tests no dependen de un Thalamus compartido. Pueden correr en paralelo.
3. **Determinista**: seeds idempotentes garantizan el mismo estado inicial siempre.
4. **Legible**: cada test es un `.sh` con assertions descriptivas. Un developer nuevo puede leerlo y entender qué se está probando.
5. **CI-first**: diseñado para GitHub Actions con matrix strategy (8 jobs paralelos).
