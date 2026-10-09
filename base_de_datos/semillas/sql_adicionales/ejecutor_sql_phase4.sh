#!/usr/bin/env bash
# ============================================================
# Ejecutor SQL Fase 4 — Kambalache v3.12
# Orquesta estructura + cargas opcionales en modo no interactivo
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
SQL_LOG_DIR="${SCRIPT_DIR}/logs"
SQL_PHASE=""
AUTO_CONFIRM=0
SKIP_VALIDATION=0

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

err() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    exit 1
}

show_help() {
    echo "Uso: $0 --phase <structure|xalapa|geo|all|post-cu-full-test> [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --phase            Fase SQL a ejecutar"
    echo "  --yes              Ejecutar sin confirmaciones interactivas"
    echo "  --skip-validation  Omitir validaciones de conteo en scripts SQL"
    echo "  --env-file         Ruta de .env"
    echo "  --log-dir          Directorio de logs SQL"
    echo "  --help             Mostrar ayuda"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --phase)
                SQL_PHASE="$2"
                shift 2
                ;;
            --phase=*)
                SQL_PHASE="${1#*=}"
                shift
                ;;
            --yes)
                AUTO_CONFIRM=1
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=1
                shift
                ;;
            --env-file)
                ENV_FILE="$2"
                shift 2
                ;;
            --env-file=*)
                ENV_FILE="${1#*=}"
                shift
                ;;
            --log-dir)
                SQL_LOG_DIR="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                err "Opción desconocida: $1"
                ;;
        esac
    done
}

run_structure() {
    local args=(--log-dir "${SQL_LOG_DIR}" --env-file "${ENV_FILE}")
    [[ "$AUTO_CONFIRM" -eq 1 ]] && args+=(--yes)
    [[ "$SKIP_VALIDATION" -eq 1 ]] && args+=(--skip-validation)
    bash "${SCRIPT_DIR}/estructura_base/crear_estructura_bd.sh" "${args[@]}"
}

run_xalapa() {
    local args=(--log-dir "${SQL_LOG_DIR}" --env-file "${ENV_FILE}")
    [[ "$AUTO_CONFIRM" -eq 1 ]] && args+=(--yes)
    [[ "$SKIP_VALIDATION" -eq 1 ]] && args+=(--skip-validation)
    bash "${SCRIPT_DIR}/datos_prueba_xalapa/poblar_datos_xalapa.sh" "${args[@]}"
}

run_geo() {
    local args=(--log-dir "${SQL_LOG_DIR}" --env-file "${ENV_FILE}")
    [[ "$AUTO_CONFIRM" -eq 1 ]] && args+=(--yes)
    [[ "$SKIP_VALIDATION" -eq 1 ]] && args+=(--skip-validation)
    bash "${SCRIPT_DIR}/datos_geoespaciales/poblar_geoespacial.sh" "${args[@]}"
}

run_post_cu_full_test() {
    local sql_file="${SCRIPT_DIR}/15_poblacion_pruebas_post_cu.sql"
    local log_file="${SQL_LOG_DIR}/post_cu_full_test_LOG_$(date +%Y%m%d_%H%M%S).txt"

    [[ -f "$sql_file" ]] || err "No se encontró SQL de post-población completa: ${sql_file}"

    log "Ejecutando post-población completa de pruebas (post-CU)"
    if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --set ON_ERROR_STOP=1 -f "$sql_file" > "$log_file" 2>&1; then
        log "Post-población completa aplicada. Log: ${log_file}"
    else
        err "Falló post-población completa. Ver: ${log_file}"
    fi
}

validate_minimum_db() {
    if [[ ! -f "$ENV_FILE" ]]; then
        err "No se encontró .env en: $ENV_FILE"
    fi

    # shellcheck disable=SC1090
    source "$ENV_FILE"

    DB_PASSWORD="${DB_PASSWORD:-${DB_PASS:-}}"
    : "${DB_HOST:=127.0.0.1}"

    : "${DB_USER:?DB_USER no definido}"
    : "${DB_PASSWORD:?DB_PASSWORD no definido}"
    : "${DB_NAME:?DB_NAME no definido}"
    : "${DB_PORT:?DB_PORT no definido}"

    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAqc "SELECT 1" >/dev/null 2>&1; then
        err "No hay conectividad a la base de datos con las credenciales de .env"
    fi
}

parse_args "$@"
mkdir -p "$SQL_LOG_DIR"

[[ -n "$SQL_PHASE" ]] || err "Debe indicar --phase"
case "$SQL_PHASE" in
    structure|xalapa|geo|all|post-cu-full-test) ;;
    *) err "--phase inválido: $SQL_PHASE" ;;
esac

if [[ "$AUTO_CONFIRM" -eq 0 ]] && [[ ! -t 0 ]]; then
    err "Sin terminal interactiva. Use --yes para ejecutar fase SQL en modo no interactivo"
fi

echo -e "${CYAN}${BOLD}=== Fase SQL (${SQL_PHASE}) ===${NC}"
validate_minimum_db

case "$SQL_PHASE" in
    structure)
        run_structure
        ;;
    xalapa)
        run_structure
        run_xalapa
        ;;
    geo|all)
        run_structure
        run_xalapa
        run_geo
        ;;
    post-cu-full-test)
        run_xalapa
        run_geo
        run_post_cu_full_test
        ;;
esac

log "Fase SQL '${SQL_PHASE}' completada"
