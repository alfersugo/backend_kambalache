#!/usr/bin/env bash
# run_tests.sh — entrypoint CI de la suite de seguridad de imágenes (Kambalache).
# SOLO entorno de test/staging. NUNCA apuntar a producción.
#
# Ejecuta:
#   1. Suite SQL unitaria/RPC (test_seguridad_imagenes.sql, 23 aserciones, ROLLBACK).
#   2. Regresión E2E HTTP PostgREST con JWT real (test_e2e_postgrest_bypass.py, TAP).
#
# Exit 0 solo si ambas pasan. Pensado para correr en el host de staging como el
# usuario del espejo (lee la config de PostgREST en runtime; no hay secretos
# versionados — ver política hardcode-cero).
set -euo pipefail
cd "$(dirname "$0")"

PGRST_CONF="${PGRST_CONF:-/home/zomitech/espejo_dev/backend/config/postgrest.conf}"

# Credenciales de BD: se extraen del db-uri de la propia config de PostgREST
# (nunca se imprimen). Formato: postgres://USER:PASS@HOST:PORT/DB
DB_URI=$(grep -E '^db-uri' "$PGRST_CONF" | sed -E 's/^db-uri[^"]*"([^"]+)".*/\1/')

echo "== [1/2] Suite SQL unitaria/RPC (unit + claims simulados) =="
SQL_OUT=$(psql "$DB_URI" -v ON_ERROR_STOP=1 -At -f test_seguridad_imagenes.sql)
# Resumen final: línea "fallos|total" (única línea num|num)
SUMMARY=$(echo "$SQL_OUT" | grep -E '^[0-9]+\|[0-9]+$' | tail -1)
FALLOS=${SUMMARY%%|*}
TOTAL=${SUMMARY##*|}
echo "SQL suite: fallos=$FALLOS total=$TOTAL"
if [ "$FALLOS" != "0" ]; then
  echo "== FALLO suite SQL ==" >&2
  echo "$SQL_OUT"
  exit 1
fi

echo "== [2/2] Regresión E2E HTTP PostgREST (JWT real) =="
PGRST_CONF="$PGRST_CONF" python3 test_e2e_postgrest_bypass.py

echo "== OK: todas las suites en verde =="
