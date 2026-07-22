#!/bin/bash
# docker-entrypoint.sh — Thalamus container entrypoint
#
# For production: just starts the app.
# For CI (SEED_ON_START=true): waits for DB, runs migrations, runs seeds, starts.
#
# Note: Migrations are NOT run by default in production — they're handled
# by the migrate_thalamus service in docker-compose.yml.

set -e

echo "═══ Thalamus Entrypoint ═══"
echo " Environment: ${MIX_ENV:-prod}"
echo " Port: ${PORT:-4000}"

# ── CI mode: wait for DB, migrate, seed ────────────────
if [ "${SEED_ON_START}" = "true" ]; then
  echo ""
  echo "── CI mode: waiting for Postgres ──"

  # Wait for DB to be ready
  for i in $(seq 1 30); do
    if bin/thalamus eval 'IO.puts("DB ready")' 2>/dev/null; then
      echo "   DB ready (${i}s)"
      break
    fi
    sleep 2
  done

  echo "── Running migrations ──"
  bin/thalamus eval 'Thalamus.Release.migrate()'

  echo "── Running seeds ──"
  bin/thalamus eval 'Code.eval_file("priv/repo/seeds.exs")'

  echo "── CI setup complete ──"
fi

# ── Start ───────────────────────────────────────────────
echo ""
echo "── Starting Thalamus on port ${PORT:-4000} ──"
exec bin/thalamus start
