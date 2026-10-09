#!/bin/bash
# Instalador seguro de Bun para Fedora/Linux
set -euo pipefail

if command -v bun &>/dev/null; then
  echo "[INFO] Bun ya está instalado: $(bun --version)"
  exit 0
fi

curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

if ! command -v bun &>/dev/null; then
  echo "[ERROR] Bun no se instaló correctamente."
  exit 1
fi

echo "[OK] Bun instalado: $(bun --version)"
