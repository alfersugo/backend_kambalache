#!/bin/bash
# start_bun_backend.sh — Inicia el backend Bun
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PORT="${BUN_BACKEND_PORT:-9000}"
[[ -f "${ROOT_DIR}/.env" ]] && set -a && source "${ROOT_DIR}/.env" && set +a
export PORT
exec bun run "${ROOT_DIR}/backend_bun/src/index.js"
