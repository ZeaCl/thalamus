#!/bin/bash
# docker-entrypoint.sh — Thalamus container entrypoint
#
# Runs migrations + seeds on every start (idempotent via Release.migrate).
# This ensures pending migrations are always applied, even when Watchtower
# restarts the container without re-running the migrate_thalamus service.
#
# CI mode (SEED_ON_START=true): waits longer for DB, then runs migrations.
# Production: quick DB wait, then migrations, then start.
set -e

echo "═══ Thalamus Entrypoint ═══"

max_wait=${DB_WAIT_RETRIES:-60}
wait_secs=2

# Wait for DB to be reachable
echo "── Waiting for DB ──"
for i in $(seq 1 $max_wait); do
  if bin/thalamus eval 'IO.puts("OK")' 2>/dev/null; then
    echo "✅ DB ready (${i}s)"
    break
  fi
  sleep $wait_secs
done

# Run migrations + seeds (idempotent &mdash; safe to run on every start)
echo "── Running migrations ──"
bin/thalamus eval 'Thalamus.Release.migrate()'
echo "── Migrations complete ──"

echo "── Starting Thalamus ──"
exec "$@"
