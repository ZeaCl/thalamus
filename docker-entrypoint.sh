#!/bin/bash
# docker-entrypoint.sh — Thalamus container entrypoint
#
# CI mode (SEED_ON_START=true): waits for DB, runs migrations + seeds, then starts.
# Production: just starts (migrations run via migrate_thalamus service).
set -e

echo "═══ Thalamus Entrypoint ═══"

if [ "${SEED_ON_START}" = "true" ]; then
  echo "── CI mode: waiting for DB ──"
  for i in $(seq 1 30); do
    if bin/thalamus eval 'IO.puts("OK")' 2>/dev/null; then break; fi
    sleep 2
  done
  echo "── Running migrations ──"
  bin/thalamus eval 'Thalamus.Release.migrate()'
  echo "── Starting Thalamus ──"
fi

exec bin/thalamus start
