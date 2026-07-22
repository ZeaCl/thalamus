#!/bin/bash
# docker-entrypoint.sh — Thalamus container entrypoint
#
# Soporta SEED_ON_START=true para contenedores efímeros de test.
# En producción, solo ejecuta migraciones y arranca.
#
# Uso:
#   docker run ... zea-thalamus                        # prod: migrate + start
#   docker run -e SEED_ON_START=true ... zea-thalamus  # test: migrate + seed + start

set -e

echo "═══ Thalamus Entrypoint ═══"
echo " Environment: ${MIX_ENV:-prod}"
echo " Port: ${PORT:-4000}"

# ── Migrations ──────────────────────────────────────────
echo ""
echo "── Running migrations ──"
bin/thalamus eval 'Thalamus.Release.migrate()'

# ── Seeds (solo si SEED_ON_START=true) ──────────────────
if [ "${SEED_ON_START}" = "true" ]; then
  echo ""
  echo "── SEED_ON_START=true — running seeds ──"
  bin/thalamus eval 'Code.eval_file("priv/repo/seeds.exs")'
  echo "── Seeds complete ──"
fi

# ── Start ───────────────────────────────────────────────
echo ""
echo "── Starting Thalamus on port ${PORT:-4000} ──"
exec bin/thalamus start
