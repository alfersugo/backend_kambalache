#!/bin/bash
# ============================================
# Script de Población de Datos Geoespaciales
# Proyecto Kambalache v3.12
# Ubicación: Ciudad de México (CDMX)
# ============================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SQL_FILE="${SCRIPT_DIR}/09_poblacion_completa_geospatial.sql"
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
LOG_FILE="${SQL_LOG_DIR}/geoespacial_cdmx_LOG_$(date +%Y%m%d_%H%M%S).txt"

echo -e "${BLUE}"
echo "═══════════════════════════════════════════════════════"
echo " POBLACIÓN DE DATOS GEOESPACIALES - CDMX"
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
source "${ENV_FILE}"
DB_PASSWORD="${DB_PASSWORD:-${DB_PASS:-}}"

# Validar variables
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
    echo "Ejecuta primero: cd ../estructura_base && ./crear_estructura_bd.sh"
    exit 1
fi
echo -e "${GREEN}✓ Base de datos '${DB_NAME}' accesible${NC}"

# Detectar modo de coordenadas (geometry o json/jsonb)
COORD_TYPE=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAqc "
SELECT data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name='articulos' AND column_name='ubicacion'
LIMIT 1;
" | xargs)

if [[ -z "$COORD_TYPE" ]]; then
    echo -e "${RED}❌ No se encontró la columna public.articulos.ubicacion${NC}"
    echo "Ejecuta primero: cd ../estructura_base && ./crear_estructura_bd.sh"
    exit 1
fi

if [[ "$COORD_TYPE" == "USER-DEFINED" ]]; then
    POSTGIS_CHECK=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAqc "SELECT COUNT(*) FROM pg_extension WHERE extname = 'postgis';" | xargs)
    if [ "$POSTGIS_CHECK" -eq 0 ] 2>/dev/null; then
        echo -e "${RED}❌ La columna ubicacion es geometry pero PostGIS no está activo${NC}"
        echo "Ejecuta: ./ORQUESTADOR.sh --post-install"
        exit 1
    fi
    COORD_MODE="postgis"
    echo -e "${GREEN}✓ Modo geoespacial detectado: PostGIS (geometry)${NC}"
else
    COORD_MODE="json"
    echo -e "${GREEN}✓ Modo geoespacial detectado: JSON/JSONB${NC}"
fi

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
echo "Este script poblará/actualizará datos geoespaciales de artículos."
echo "Ubicación: Ciudad de México (CDMX)"
echo "Se actualizarán coordenadas (JSON/PostGIS según esquema) y direcciones de artículos existentes."
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
echo "=== Ejecutando Script de Datos Geoespaciales ==="
echo -e "${BLUE}Esto puede tomar unos segundos...${NC}"

if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --set ON_ERROR_STOP=1 -f "${SQL_FILE}" > "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}✓ Script ejecutado exitosamente${NC}"
else
    echo -e "${RED}❌ Error al ejecutar el script${NC}"
    echo "Ver detalles en: ${LOG_FILE}"
    tail -20 "$LOG_FILE"
    exit 1
fi

# ============================================
# VALIDACIÓN DE DATOS GEOESPACIALES
# ============================================

echo ""
echo "=== Validación de Datos Geoespaciales ==="

query_db() {
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "$1" | xargs
}

if [[ "$SKIP_VALIDATION" -eq 1 ]]; then
    echo -e "${YELLOW}⚠ Validación omitida por --skip-validation${NC}"
    ARTICULOS_GEO="N/A"
    UBICACIONES="N/A"
else
    ARTICULOS_GEO=$(query_db "SELECT COUNT(*) FROM articulos WHERE ubicacion IS NOT NULL;")
    UBICACIONES=$(query_db "SELECT COUNT(*) FROM ubicaciones;" 2>/dev/null || echo "0")
fi

# ============================================
# RESUMEN FINAL
# ============================================

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} DATOS GEOESPACIALES POBLADOS EXITOSAMENTE${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "📊 Resumen de Datos Geoespaciales:"
echo ""
echo "📍 Artículos con ubicación: ${ARTICULOS_GEO}"
echo "🗺️  Ubicaciones registradas: ${UBICACIONES}"
echo "🏙️  Zona: Ciudad de México (CDMX)"
echo "🧭 Modo coordenadas: ${COORD_MODE}"
echo ""
echo -e "${BLUE}Puedes verificar los datos con:${NC}"
if [[ "${COORD_MODE}" == "postgis" ]]; then
    echo "  psql -U ${DB_USER} -d ${DB_NAME} -c \"SELECT id, titulo, ST_AsText(ubicacion) FROM articulos WHERE ubicacion IS NOT NULL;\""
else
    echo "  psql -U ${DB_USER} -d ${DB_NAME} -c \"SELECT id, titulo, ubicacion FROM articulos WHERE ubicacion IS NOT NULL;\""
fi
echo ""
echo "📄 Log de ejecución: ${LOG_FILE}"
echo ""
