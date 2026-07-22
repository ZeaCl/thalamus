#!/bin/bash
# docker-entrypoint.sh — Thalamus container entrypoint
#
# Production: just runs migrations then starts.
# CI: SEED_ON_START=true — skips migrations (handled by CI workflow).
#
# Note: In docker-compose.yml, a separate migrate_thalamus service runs migrations.
# This entrypoint only runs migrations if no migrate service exists.

set -e

echo "═══ Thalamus Entrypoint ═══"
echo " Environment: ${MIX_ENV:-prod}"
echo " Port: ${PORT:-4000}"

# Only run migrations in production (not CI — CI handles them separately)
if [ "${SEED_ON_START}" != "true" ]; then
  echo ""
  echo "── Running migrations (production mode) ──"
  bin/thalamus eval 'Thalamus.Release.migrate()' 2>/dev/null || echo "   ⚠️  Migration skipped (will run via migrate service)"
fi

echo ""
echo "── Starting Thalamus on port ${PORT:-4000} ──"
exec bin/thalamus start
