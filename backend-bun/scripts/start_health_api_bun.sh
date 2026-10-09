#!/bin/bash
# Script para lanzar el endpoint de health check del backend Bun
set -euo pipefail

cd "$(dirname "$0")/../src"

# Lanzar el servicio en background en el puerto 4050
nohup bun run health.js &> /tmp/health_api_bun.log &
echo "[OK] health.js lanzado en http://localhost:4050/api/bun/health"
