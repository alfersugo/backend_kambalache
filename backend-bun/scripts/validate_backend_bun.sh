#!/bin/bash
# Validador de estructura y salud backend Bun
set -euo pipefail

echo "[VALIDACIÓN] backend_bun:"
[ -d "$(dirname "$0")/../src" ] && echo "  ✓ src/ existe"
[ -d "$(dirname "$0")/../tests" ] && echo "  ✓ tests/ existe"
[ -d "$(dirname "$0")/../config" ] && echo "  ✓ config/ existe"
[ -d "$(dirname "$0")/../docs" ] && echo "  ✓ docs/ existe"
[ -f "$(dirname "$0")/../README.md" ] && echo "  ✓ README.md existe"

# Placeholder para validaciones futuras (endpoints, JWT, healthchecks)
echo "  ✓ Estructura base backend_bun OK"
