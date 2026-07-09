#!/usr/bin/env bash
# ==============================================================================
# migrate-db.sh — Script maestro orquestador
#
# Ejecuta el flujo completo de migración:
#   STOP legacy → DUMP → DEPLOY external DB → RESTORE → START legacy
#
# Automáticamente detecta podman o docker (podman tiene prioridad).
#
# Modos:
#   --ocp               Flujo completo en OpenShift
#   --container         Flujo completo en contenedor local (Docker o Podman)
#   --ocp-dump-only     Solo extrae el dump del pod OCP (sin restaurar)
#   --dump-only [ctr]   Solo extrae el dump del contenedor local (sin restaurar)
#   --restore-ocp   <dump>       Solo restaura en la BD OCP (ya desplegada)
#   --restore-container <dump>   Solo restaura en la BD externa (ya corriendo)
#
# Uso:
#   ./migrate-db.sh --ocp
#   ./migrate-db.sh --container [container_name]
#   ./migrate-db.sh --restore-ocp       ./dumps/f1-legacy-dump-YYYYMMDD.sql
#   ./migrate-db.sh --restore-container ./dumps/f1-legacy-dump-YYYYMMDD.sql
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
OCP_DIR="${SCRIPT_DIR}/ocp"
CONTAINER_DIR="${SCRIPT_DIR}/container"
DUMPS_DIR="${SCRIPT_DIR}/dumps"

mkdir -p "${DUMPS_DIR}"

# ---------------------------------------------------------------------------
# Detectar runtime: podman tiene prioridad sobre docker
# ---------------------------------------------------------------------------
if command -v podman &>/dev/null; then
    CTR="podman"
    COMPOSE="podman compose"
elif command -v docker &>/dev/null; then
    CTR="docker"
    COMPOSE="docker compose"
else
    echo "✗ Neither podman nor docker found. Please install one of them." >&2
    exit 1
fi

echo "→ Using container runtime: ${CTR}"

# ---------------------------------------------------------------------------
# Colores y utilidades de logging
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_step()  { echo -e "\n${CYAN}${BOLD}━━━ $* ━━━${RESET}"; }
log_ok()    { echo -e "${GREEN}✓${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}⚠${RESET}  $*"; }
log_error() { echo -e "${RED}✗${RESET} $*"; }

print_banner() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║      F1-Tickets — Migración de Base de Datos                 ║${RESET}"
    echo -e "${BOLD}║      Legacy (monolito) → BD Externa independiente            ║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_summary() {
    local mode="${1}"
    local dump_file="${2:-<pendiente>}"
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║  ✓  MIGRACIÓN COMPLETADA                                     ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "  Dump generado : ${dump_file}"
    echo "  Modo          : ${mode}"
    echo "  Runtime       : ${CTR}"
    echo ""
    if [[ "${mode}" == "ocp" ]]; then
        echo "  ┌─ Acceso a la BD externa en OCP ──────────────────────────────┐"
        echo "  │  Host: f1-external-db.f1-tickets-db.svc.cluster.local        │"
        echo "  │  Port: 5432                                                   │"
        echo "  │  User: appuser  │  Pass: apppassword  │  DB: appdb            │"
        echo "  │  URL : postgresql://appuser:apppassword@                      │"
        echo "  │        f1-external-db.f1-tickets-db.svc.cluster.local:5432/  │"
        echo "  │        appdb                                                  │"
        echo "  └──────────────────────────────────────────────────────────────┘"
    else
        echo "  ┌─ Acceso a la BD externa (local) ─────────────────────────────┐"
        echo "  │  Host: localhost                                              │"
        echo "  │  Port: 5433                                                   │"
        echo "  │  User: appuser  │  Pass: apppassword  │  DB: appdb            │"
        echo "  │  URL : postgresql://appuser:apppassword@localhost:5433/appdb  │"
        echo "  └──────────────────────────────────────────────────────────────┘"
    fi
    echo ""
    echo "  La aplicación legacy sigue operativa con su BD interna."
    echo "  La BD externa está lista para la aplicación modernizada."
    echo ""
}

# ---------------------------------------------------------------------------
# Flujo OCP completo
# ---------------------------------------------------------------------------
run_ocp() {
    print_banner
    log_step "MODO: OpenShift — flujo completo"

    if ! command -v oc &>/dev/null; then
        log_error "oc CLI no encontrado. Instálalo desde https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
        exit 1
    fi
    if ! oc whoami &>/dev/null; then
        log_error "No hay sesión oc activa. Ejecuta: oc login <cluster_url>"
        exit 1
    fi
    log_ok "Sesión OCP activa: $(oc whoami)"

    # FASE 1 — Dump
    log_step "FASE 1/3 — Extracción del dump desde el pod legacy"
    bash "${SCRIPTS_DIR}/01-dump-from-legacy-ocp.sh" "${DUMPS_DIR}"

    DUMP_FILE=$(ls -t "${DUMPS_DIR}"/f1-legacy-dump-*.sql 2>/dev/null | head -1)
    if [[ -z "${DUMP_FILE}" ]]; then
        log_error "No se encontró el fichero de dump en ${DUMPS_DIR}"
        exit 1
    fi
    log_ok "Dump disponible: ${DUMP_FILE}"

    # FASE 2 — Desplegar BD externa
    log_step "FASE 2/3 — Despliegue de la BD externa en OCP (namespace f1-tickets-db)"
    log_warn "IMPORTANTE: Edita ${OCP_DIR}/deploy-external-db-ocp.yaml"
    log_warn "            y reemplaza <STORAGE_CLASSNAME> antes de continuar."
    echo ""
    read -r -p "  ¿Has configurado el StorageClassName? [s/N] " confirm
    if [[ ! "${confirm}" =~ ^[sS]$ ]]; then
        log_warn "Edita el fichero y vuelve a ejecutar: $0 --restore-ocp ${DUMP_FILE}"
        exit 0
    fi

    oc apply -f "${OCP_DIR}/deploy-external-db-ocp.yaml"
    log_ok "Manifiesto aplicado. Esperando que el deployment esté listo..."
    oc rollout status deployment/f1-external-db -n f1-tickets-db --timeout=180s
    log_ok "BD externa desplegada."

    # FASE 3 — Restaurar dump
    log_step "FASE 3/3 — Restauración del dump en la BD externa"
    bash "${SCRIPTS_DIR}/03-restore-dump-ocp.sh" "${DUMP_FILE}"

    print_summary "ocp" "${DUMP_FILE}"
}

# ---------------------------------------------------------------------------
# Flujo contenedor local completo (Docker o Podman)
# ---------------------------------------------------------------------------
run_container() {
    local container="${1:-}"
    print_banner
    log_step "MODO: contenedor local (${CTR}) — flujo completo"

    # FASE 1 — Dump
    log_step "FASE 1/3 — Extracción del dump desde el contenedor legacy"
    bash "${SCRIPTS_DIR}/01-dump-from-legacy-container.sh" "${container}" "${DUMPS_DIR}"

    DUMP_FILE=$(ls -t "${DUMPS_DIR}"/f1-legacy-dump-*.sql 2>/dev/null | head -1)
    if [[ -z "${DUMP_FILE}" ]]; then
        log_error "No se encontró el fichero de dump en ${DUMPS_DIR}"
        exit 1
    fi
    log_ok "Dump disponible: ${DUMP_FILE}"

    # FASE 2 — Levantar BD externa con compose
    log_step "FASE 2/3 — Levantando BD externa con ${CTR} compose"
    ${COMPOSE} -f "${CONTAINER_DIR}/compose.yml" up -d
    log_ok "Contenedor f1-external-db levantado."

    echo "  Esperando que PostgreSQL esté listo..."
    MAX_WAIT=60; WAITED=0
    until ${CTR} exec f1-external-db pg_isready -U appuser -d appdb &>/dev/null; do
        if [[ $WAITED -ge $MAX_WAIT ]]; then
            log_error "PostgreSQL no respondió en ${MAX_WAIT}s."
            exit 1
        fi
        echo "  … esperando (${WAITED}s)..."
        sleep 5; WAITED=$((WAITED + 5))
    done
    log_ok "PostgreSQL listo."

    # FASE 3 — Restaurar dump
    log_step "FASE 3/3 — Restauración del dump en la BD externa"
    bash "${SCRIPTS_DIR}/03-restore-dump-container.sh" "${DUMP_FILE}"

    print_summary "container" "${DUMP_FILE}"
}

# ---------------------------------------------------------------------------
# Punto de entrada — parseo de argumentos
# ---------------------------------------------------------------------------
MODE="${1:-}"

case "${MODE}" in
    --ocp)
        run_ocp
        ;;
    --container)
        run_container "${2:-}"
        ;;
    --ocp-dump-only)
        print_banner
        bash "${SCRIPTS_DIR}/01-dump-from-legacy-ocp.sh" "${DUMPS_DIR}"
        ;;
    --dump-only)
        print_banner
        bash "${SCRIPTS_DIR}/01-dump-from-legacy-container.sh" "${2:-}" "${DUMPS_DIR}"
        ;;
    --restore-ocp)
        DUMP="${2:-}"
        if [[ -z "${DUMP}" ]]; then
            log_error "Uso: $0 --restore-ocp <dump_file>"
            exit 1
        fi
        print_banner
        if ! oc get deployment f1-external-db -n f1-tickets-db &>/dev/null; then
            log_warn "La BD externa no está desplegada. Aplicando manifiesto..."
            oc apply -f "${OCP_DIR}/deploy-external-db-ocp.yaml"
            oc rollout status deployment/f1-external-db -n f1-tickets-db --timeout=180s
        fi
        bash "${SCRIPTS_DIR}/03-restore-dump-ocp.sh" "${DUMP}"
        ;;
    --restore-container)
        DUMP="${2:-}"
        if [[ -z "${DUMP}" ]]; then
            log_error "Uso: $0 --restore-container <dump_file>"
            exit 1
        fi
        print_banner
        if ! ${CTR} ps --filter name=f1-external-db --filter status=running \
             --format "{{.Names}}" 2>/dev/null | grep -q f1-external-db; then
            log_warn "El contenedor f1-external-db no está corriendo. Levantando..."
            ${COMPOSE} -f "${CONTAINER_DIR}/compose.yml" up -d
        fi
        bash "${SCRIPTS_DIR}/03-restore-dump-container.sh" "${DUMP}"
        ;;
    *)
        print_banner
        echo "Uso: $0 <modo> [opciones]"
        echo ""
        echo "  Runtime detectado: ${CTR}"
        echo ""
        echo "  Modos disponibles:"
        echo "    --ocp                        Flujo completo en OpenShift"
        echo "    --container [container]      Flujo completo (${CTR} local)"
        echo "    --ocp-dump-only              Solo extrae dump del pod OCP"
        echo "    --dump-only [container]      Solo extrae dump del contenedor local"
        echo "    --restore-ocp <dump>         Solo restaura dump en BD externa OCP"
        echo "    --restore-container <dump>   Solo restaura dump en BD externa local"
        echo ""
        echo "  Ejemplos:"
        echo "    $0 --ocp"
        echo "    $0 --container f1-tickets"
        echo "    $0 --restore-ocp       ./dumps/f1-legacy-dump-20260101-120000.sql"
        echo "    $0 --restore-container ./dumps/f1-legacy-dump-20260101-120000.sql"
        echo ""
        exit 1
        ;;
esac
