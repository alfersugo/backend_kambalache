#!/bin/bash
# ============================================
# Script de Creación de Estructura de BD
# Proyecto Kambalache v3.12
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
LOG_FILE="${SQL_LOG_DIR}/estructura_bd_LOG_$(date +%Y%m%d_%H%M%S).txt"

# Banner
echo -e "${BLUE}"
echo "═══════════════════════════════════════════════════════"
echo " CREACIÓN DE ESTRUCTURA DE BASE DE DATOS"
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
    echo "  sudo -u postgres psql -c \"CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};\""
    exit 1
fi
echo -e "${GREEN}✓ Base de datos '${DB_NAME}' accesible${NC}"

# Verificar que los archivos SQL existen
SQL_FILES=("01_extensiones_y_esquema.sql" "02_tablas_catalogos.sql" "03_tablas_negocio.sql" "04_triggers_rls.sql" "05_funciones_rpc.sql" "06_indices_fulltext.sql" "07_datos_prueba.sql" "08_documentacion_erd.sql" "11_visualizacion_schema_grafo.sql" "12_reportes_analitica.sql" "13_grafos_recomendaciones.sql" "14_indices_fase4.sql")

for sql_file in "${SQL_FILES[@]}"; do
    if [ ! -f "${SCRIPT_DIR}/${sql_file}" ]; then
        echo -e "${RED}❌ No se encontró: ${sql_file}${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ Todos los archivos SQL encontrados (${#SQL_FILES[@]} archivos)${NC}"

# ============================================
# CONFIRMACIÓN DEL USUARIO
# ============================================

echo ""
echo -e "${YELLOW}⚠️  ADVERTENCIA:${NC}"
echo "Este script creará la estructura completa de la base de datos."
echo "Esto incluye: extensiones, esquemas, tablas, triggers, RLS, funciones e índices."
echo ""
echo "📋 Scripts a ejecutar:"
for sql_file in "${SQL_FILES[@]}"; do
    echo "   - ${sql_file}"
done
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
# FUNCIÓN PARA EJECUTAR SQL
# ============================================

execute_sql() {
    local file=$1
    local description=$2

    echo -e "${BLUE}Ejecutando: ${description}...${NC}"

    if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --set ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/${file}" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✓ ${description} completado${NC}"
    else
        echo -e "${RED}❌ Error en ${description}${NC}"
        echo "Ver detalles en: ${LOG_FILE}"
        tail -20 "$LOG_FILE"
        exit 1
    fi
}

# ============================================
# EJECUCIÓN DE SCRIPTS EN ORDEN
# ============================================

echo ""
echo "=== Creando Estructura de Base de Datos ==="
echo ""

# Inicializar log
: > "$LOG_FILE"

execute_sql "01_extensiones_y_esquema.sql" "Extensiones y Esquema"
execute_sql "02_tablas_catalogos.sql" "Tablas de Catálogos"
execute_sql "03_tablas_negocio.sql" "Tablas de Negocio"
execute_sql "04_triggers_rls.sql" "Triggers y RLS"
execute_sql "05_funciones_rpc.sql" "Funciones RPC"
execute_sql "06_indices_fulltext.sql" "Índices y Full-Text"
execute_sql "07_datos_prueba.sql" "Datos de Prueba Básicos"
execute_sql "08_documentacion_erd.sql" "Documentación ERD"
execute_sql "11_visualizacion_schema_grafo.sql" "Visualización de Schema y Grafo"
execute_sql "12_reportes_analitica.sql" "RPC de Reportes y Analítica"
execute_sql "13_grafos_recomendaciones.sql" "Grafos, Recomendaciones y Geoespacial"
execute_sql "14_indices_fase4.sql" "Índices de Rendimiento Fase 4"

# Migración opcional: si hay PostGIS disponible, crear columnas geometry sombra
MIGRATION_SQL="${SCRIPT_DIR}/09_migracion_json_a_geometry_shadow.sql"
POSTGIS_OK="$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAqc "SELECT 1 FROM pg_extension WHERE extname='postgis';" 2>/dev/null || true)"
if [[ -f "${MIGRATION_SQL}" && "${POSTGIS_OK}" == "1" ]]; then
    echo -e "${BLUE}Ejecutando: Migración JSON->geometry (columnas sombra)...${NC}"
    if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --set ON_ERROR_STOP=1 -f "${MIGRATION_SQL}" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✓ Migración JSON->geometry completada${NC}"
    else
        echo -e "${YELLOW}⚠ Migración JSON->geometry no aplicada. Continuando con estructura JSON actual.${NC}"
    fi
fi

# ============================================
# VALIDACIÓN DE ESTRUCTURA
# ============================================

echo ""
echo "=== Validación de Estructura ==="
if [[ "$SKIP_VALIDATION" -eq 1 ]]; then
    echo -e "${YELLOW}⚠ Validación omitida por --skip-validation${NC}"
    TOTAL_TABLAS="N/A"
    TOTAL_TRIGGERS="N/A"
    TOTAL_FUNCIONES="N/A"
    TOTAL_INDICES="N/A"
    TOTAL_SCHEMA_VIEWS="N/A"
else

query_db() {
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "$1" | xargs
}

TOTAL_TABLAS=$(query_db "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
TOTAL_TRIGGERS=$(query_db "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = 'public';")
TOTAL_FUNCIONES=$(query_db "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public';")
TOTAL_INDICES=$(query_db "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';")
TOTAL_SCHEMA_VIEWS=$(query_db "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='public' AND table_name IN ('vw_schema_tablas','vw_schema_relaciones_fk','vw_grafo_nodos','vw_grafo_aristas','vw_grafo_age_estado');")
fi

# ============================================
# RESUMEN FINAL
# ============================================

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} ESTRUCTURA CREADA EXITOSAMENTE${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "📊 Resumen de Estructura:"
echo ""
echo "📋 Tablas creadas: ${TOTAL_TABLAS}"
echo "⚡ Triggers creados: ${TOTAL_TRIGGERS}"
echo "🔧 Funciones RPC creadas: ${TOTAL_FUNCIONES}"
echo "🔍 Índices creados: ${TOTAL_INDICES}"
echo "🧩 Vistas schema/grafo: ${TOTAL_SCHEMA_VIEWS}"
echo ""
echo -e "${BLUE}Próximos pasos opcionales:${NC}"
echo "  1. Poblar datos de prueba de Xalapa:"
echo "     cd ../datos_prueba_xalapa && ./poblar_datos_xalapa.sh"
echo ""
echo "  2. Poblar datos geoespaciales CDMX:"
echo "     cd ../datos_geoespaciales && ./poblar_geoespacial.sh"
echo ""
echo "📄 Log de ejecución: ${LOG_FILE}"
echo ""
