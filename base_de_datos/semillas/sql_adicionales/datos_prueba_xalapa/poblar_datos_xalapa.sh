#!/bin/bash
# ============================================
# Script de Población de Datos de Prueba
# Proyecto Kambalache v3.12
# Ubicación: Xalapa, Veracruz
# ============================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SQL_FILE="${SCRIPT_DIR}/10_poblacion_completa_xalapa.sql"
AUTO_CONFIRM=0
SKIP_VALIDATION=0
SQL_LOG_DIR="${SQL_ROOT_DIR}/logs"
ENV_FILE_OVERRIDE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes)
                AUTO_CONFIRM=1
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=1
                shift
                ;;
            --log-dir)
                SQL_LOG_DIR="$2"
                shift 2
                ;;
            --env-file)
                ENV_FILE_OVERRIDE="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}❌ Opción no válida: $1${NC}"
                exit 1
                ;;
        esac
    done
}

parse_args "$@"
mkdir -p "$SQL_LOG_DIR"
LOG_FILE="${SQL_LOG_DIR}/poblacion_xalapa_LOG_$(date +%Y%m%d_%H%M%S).txt"

echo -e "${BLUE}"
echo "═══════════════════════════════════════════════════════"
echo " POBLACIÓN DE DATOS DE PRUEBA - XALAPA"
echo " Proyecto Kambalache v3.12"
echo "═══════════════════════════════════════════════════════"
echo -e "${NC}"

# ============================================
# BUSCAR ARCHIVO .env
# ============================================

if [[ -n "${ENV_FILE_OVERRIDE}" ]]; then
    if [[ ! -f "${ENV_FILE_OVERRIDE}" ]]; then
        echo -e "${RED}❌ --env-file no existe: ${ENV_FILE_OVERRIDE}${NC}"
        exit 1
    fi
    ENV_FILE="${ENV_FILE_OVERRIDE}"
elif [ -f "/opt/kambalache/.env" ]; then
    ENV_FILE="/opt/kambalache/.env"
elif [ -f "${SCRIPT_DIR}/../../.env" ]; then
    ENV_FILE="${SCRIPT_DIR}/../../.env"
elif [ -f "${HOME}/.env" ]; then
    ENV_FILE="${HOME}/.env"
else
    echo -e "${RED}❌ No se encontró archivo .env${NC}"
    echo "Ubicaciones buscadas:"
    echo "  - /opt/kambalache/.env"
    echo "  - ${SCRIPT_DIR}/../../.env"
    echo "  - ${HOME}/.env"
    exit 1
fi

echo -e "${GREEN}✓ Archivo .env encontrado: ${ENV_FILE}${NC}"

# Cargar variables del .env
source "${ENV_FILE}"
DB_PASSWORD="${DB_PASSWORD:-${DB_PASS:-}}"

# Validar que las variables existen
if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_NAME" ] || [ -z "$DB_PORT" ]; then
    echo -e "${RED}❌ Faltan variables en .env (DB_USER, DB_PASSWORD, DB_NAME, DB_PORT)${NC}"
    exit 1
fi
: "${DB_HOST:=127.0.0.1}"

# ============================================
# VALIDACIONES PREVIAS
# ============================================

echo ""
echo "=== Validaciones Previas ==="

# Validar que PostgreSQL está corriendo
if ! systemctl is-active --quiet postgresql; then
    echo -e "${RED}❌ PostgreSQL no está corriendo${NC}"
    echo "Ejecuta: sudo systemctl start postgresql"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL está activo${NC}"

# Validar conectividad/autenticación y existencia de la BD en un solo paso
# (kambalache_user solo tiene acceso a la BD kambalache, no a postgres)
if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAqc "SELECT 1" >/dev/null 2>&1; then
    echo -e "${RED}❌ No se pudo autenticar o conectar con la base de datos '${DB_NAME}'.${NC}"
    echo "Verifica: pg_hba.conf, credenciales en .env, y que la BD '${DB_NAME}' exista."
    echo "Ejecuta primero el script de instalación de estructura SQL."
    exit 1
fi
echo -e "${GREEN}✓ Base de datos '${DB_NAME}' accesible${NC}"

# Validar que el archivo SQL existe
if [ ! -f "${SQL_FILE}" ]; then
    echo -e "${RED}❌ No se encontró el archivo SQL: ${SQL_FILE}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Archivo SQL encontrado${NC}"

# ============================================
# CONFIRMACIÓN DEL USUARIO
# ============================================

echo ""
echo -e "${YELLOW}⚠️  ADVERTENCIA:${NC}"
echo "Este script poblará la base de datos con datos de prueba."
echo "Si ya existen datos, algunos podrían ser eliminados o duplicados."
echo ""
if [[ "$AUTO_CONFIRM" -eq 1 ]]; then
    echo -e "${GREEN}✓ Confirmación automática habilitada (--yes)${NC}"
elif [[ -t 0 ]]; then
    read -p "¿Deseas continuar? (s/N): " CONFIRM
    CONFIRM=${CONFIRM:-N}

    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
        echo -e "${YELLOW}Operación cancelada${NC}"
        exit 0
    fi
else
    echo -e "${RED}❌ No hay terminal interactiva. Use --yes para continuar.${NC}"
    exit 1
fi

# ============================================
# EJECUCIÓN DEL SCRIPT SQL
# ============================================

echo ""
echo "=== Ejecutando Script de Población ==="
echo -e "${BLUE}Esto puede tomar unos minutos...${NC}"

# Ejecutar el script SQL
if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --set ON_ERROR_STOP=1 -f "${SQL_FILE}" > "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}✓ Script ejecutado exitosamente${NC}"
else
    echo -e "${RED}❌ Error al ejecutar el script${NC}"
    echo "Ver detalles en: ${LOG_FILE}"
    tail -20 "$LOG_FILE"
    exit 1
fi

# ============================================
# VALIDACIÓN DE DATOS CREADOS
# ============================================

echo ""
echo "=== Validación de Datos Creados ==="

# Función para ejecutar query y obtener resultado
query_db() {
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "$1" | xargs
}

if [[ "$SKIP_VALIDATION" -eq 1 ]]; then
    echo -e "${YELLOW}⚠ Validación omitida por --skip-validation${NC}"
    ADMIN_COUNT="N/A"
    MODERADOR_COUNT="N/A"
    USUARIO_COUNT="N/A"
    TOTAL_USUARIOS="N/A"
    TOTAL_ARTICULOS="N/A"
    TOTAL_TRUEQUES="N/A"
    TOTAL_RATINGS="N/A"
    TOTAL_ALERTAS="N/A"
    TOTAL_PROMOCIONES="N/A"
else
    # Contar usuarios por rol
    ADMIN_COUNT=$(query_db "SELECT COUNT(*) FROM usuario_roles ur JOIN roles r ON ur.rol_id = r.id WHERE r.nombre = 'admin';")
    MODERADOR_COUNT=$(query_db "SELECT COUNT(*) FROM usuario_roles ur JOIN roles r ON ur.rol_id = r.id WHERE r.nombre = 'moderador';")
    USUARIO_COUNT=$(query_db "SELECT COUNT(*) FROM usuario_roles ur JOIN roles r ON ur.rol_id = r.id WHERE r.nombre = 'usuario';")
    TOTAL_USUARIOS=$(query_db "SELECT COUNT(*) FROM usuarios;")

    # Contar artículos
    TOTAL_ARTICULOS=$(query_db "SELECT COUNT(*) FROM articulos;")

    # Contar intercambios
    TOTAL_TRUEQUES=$(query_db "SELECT COUNT(*) FROM intercambios;")

    # Contar ratings
    TOTAL_RATINGS=$(query_db "SELECT COUNT(*) FROM ratings;")

    # Contar alertas
    TOTAL_ALERTAS=$(query_db "SELECT COUNT(*) FROM admin_alerts;")

    # Contar promociones
    TOTAL_PROMOCIONES=$(query_db "SELECT COUNT(*) FROM promociones;")
fi

# ============================================
# RESUMEN FINAL
# ============================================

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} POBLACIÓN COMPLETADA EXITOSAMENTE${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "📊 Resumen de Datos Creados:"
echo ""
echo "👥 Usuarios:"
echo "   - Administradores: ${ADMIN_COUNT}"
echo "   - Moderadores:     ${MODERADOR_COUNT}"
echo "   - Usuarios:        ${USUARIO_COUNT}"
echo "   - Total:           ${TOTAL_USUARIOS}"
echo ""
echo "📦 Artículos: ${TOTAL_ARTICULOS}"
echo "🔄 Intercambios: ${TOTAL_TRUEQUES}"
echo "⭐ Ratings: ${TOTAL_RATINGS}"
echo "🚨 Alertas Admin: ${TOTAL_ALERTAS}"
echo "🎁 Promociones: ${TOTAL_PROMOCIONES}"
echo ""
echo "📍 Ubicación: Xalapa, Veracruz"
echo ""
echo -e "${BLUE}Puedes consultar los datos con:${NC}"
echo "  psql -U ${DB_USER} -d ${DB_NAME}"
echo "📄 Log de ejecución: ${LOG_FILE}"
echo ""
