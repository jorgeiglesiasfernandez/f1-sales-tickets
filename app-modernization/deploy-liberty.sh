#!/usr/bin/env bash
# ==============================================================================
# deploy-liberty.sh — Script maestro orquestador
#
# Ejecuta el flujo completo de despliegue de la aplicación modernizada
# F1-Tickets sobre IBM WebSphere Liberty 25.
#
# Automáticamente detecta podman o docker (podman tiene prioridad).
#
# Modos:
#   --ocp                    Flujo completo en OpenShift (build + deploy)
#   --container              Flujo completo en contenedor local (build + deploy)
#   --ocp-build-only         Solo lanza el build en OCP (sin desplegar)
#   --build-only             Solo construye la imagen local (sin desplegar)
#   --deploy-ocp             Solo despliega en OCP (imagen ya construida)
#   --deploy-container       Solo despliega en contenedor local (imagen ya construida)
#
# Uso:
#   ./deploy-liberty.sh --ocp
#   ./deploy-liberty.sh --container
#   ./deploy-liberty.sh --ocp-build-only
#   ./deploy-liberty.sh --build-only [image_tag]
#   ./deploy-liberty.sh --deploy-ocp
#   ./deploy-liberty.sh --deploy-container [image_tag]
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
OCP_DIR="${SCRIPT_DIR}/ocp"
CONTAINER_DIR="${SCRIPT_DIR}/container"

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
    echo -e "${BOLD}║  F1-Tickets — Despliegue App Modernizada (Liberty 25)        ║${RESET}"
    echo -e "${BOLD}║  Legacy (WildFly 18) → IBM WebSphere Liberty 25              ║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_summary_ocp() {
    local route_host="${1:-<pendiente>}"
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║  ✓  DESPLIEGUE OCP COMPLETADO                                ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "  Namespace    : f1-tickets-modern"
    echo "  Runtime      : Liberty 25"
    echo ""
    echo "  ┌─ URLs de acceso ──────────────────────────────────────────┐"
    echo "  │  Web UI  : https://${route_host}/f1-tickets"
    echo "  │  REST API: https://${route_host}/f1-tickets/api/events"
    echo "  └────────────────────────────────────────────────────────────┘"
    echo ""
    echo "  ┌─ BD externa (cluster) ────────────────────────────────────┐"
    echo "  │  Host: f1-external-db.f1-tickets-db.svc.cluster.local     │"
    echo "  │  Port: 5432  │  User: appuser  │  DB: appdb               │"
    echo "  └────────────────────────────────────────────────────────────┘"
    echo ""
}

print_summary_container() {
    local image_tag="${1:-f1-liberty:latest}"
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║  ✓  DESPLIEGUE LOCAL COMPLETADO                              ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "  Imagen       : ${image_tag}"
    echo "  Runtime      : ${CTR}"
    echo ""
    echo "  ┌─ URLs de acceso ──────────────────────────────────────────┐"
    echo "  │  Web UI  : http://localhost:9080/f1-tickets               │"
    echo "  │  REST API: http://localhost:9080/f1-tickets/api/events    │"
    echo "  │  HTTPS   : https://localhost:9443/f1-tickets              │"
    echo "  └────────────────────────────────────────────────────────────┘"
    echo ""
    echo "  ┌─ BD externa (local) ──────────────────────────────────────┐"
    echo "  │  Host: localhost  │  Port: 5433                           │"
    echo "  │  User: appuser    │  DB: appdb                            │"
    echo "  │  URL : postgresql://appuser:apppassword@localhost:5433/   │"
    echo "  │        appdb                                               │"
    echo "  └────────────────────────────────────────────────────────────┘"
    echo ""
}

# ---------------------------------------------------------------------------
# Flujo OCP completo (build + deploy)
# ---------------------------------------------------------------------------
run_ocp() {
    print_banner
    log_step "MODO: OpenShift — flujo completo (build + deploy)"

    if ! command -v oc &>/dev/null; then
        log_error "oc CLI no encontrado. Instálalo desde https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
        exit 1
    fi
    if ! oc whoami &>/dev/null; then
        log_error "No hay sesión oc activa. Ejecuta: oc login <cluster_url>"
        exit 1
    fi
    log_ok "Sesión OCP activa: $(oc whoami)"

    # FASE 1 — Aplicar manifiesto si es necesario
    log_step "FASE 1/3 — Preparando recursos en OCP"
    if ! oc get project f1-tickets-modern &>/dev/null; then
        log_warn "Namespace 'f1-tickets-modern' no existe. Aplicando manifiesto..."
        oc apply -f "${OCP_DIR}/deploy-liberty-ocp.yaml"
        log_ok "Manifiesto aplicado."
    else
        log_ok "Namespace 'f1-tickets-modern' ya existe."
    fi

    # FASE 2 — Build de la imagen
    log_step "FASE 2/3 — Build de imagen Liberty en OCP"
    bash "${SCRIPTS_DIR}/01-build-image-ocp.sh"

    # FASE 3 — Despliegue
    log_step "FASE 3/3 — Despliegue de la aplicación Liberty"
    bash "${SCRIPTS_DIR}/02-deploy-ocp.sh"

    ROUTE_HOST=$(oc get route f1-liberty -n f1-tickets-modern \
        --template='{{.spec.host}}' 2>/dev/null || echo "<route-pendiente>")
    print_summary_ocp "${ROUTE_HOST}"
}

# ---------------------------------------------------------------------------
# Flujo contenedor local completo (build + deploy)
# ---------------------------------------------------------------------------
run_container() {
    local image_tag="${1:-f1-liberty:latest}"
    print_banner
    log_step "MODO: contenedor local (${CTR}) — flujo completo (build + deploy)"

    # FASE 1 — Build de la imagen
    log_step "FASE 1/2 — Build de imagen Liberty con ${CTR}"
    bash "${SCRIPTS_DIR}/01-build-image-container.sh" "${image_tag}"

    # FASE 2 — Despliegue
    log_step "FASE 2/2 — Despliegue de la aplicación Liberty"
    bash "${SCRIPTS_DIR}/02-deploy-container.sh" "${image_tag}"

    print_summary_container "${image_tag}"
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
        run_container "${2:-f1-liberty:latest}"
        ;;
    --ocp-build-only)
        print_banner
        bash "${SCRIPTS_DIR}/01-build-image-ocp.sh"
        ;;
    --build-only)
        print_banner
        bash "${SCRIPTS_DIR}/01-build-image-container.sh" "${2:-f1-liberty:latest}"
        ;;
    --deploy-ocp)
        print_banner
        bash "${SCRIPTS_DIR}/02-deploy-ocp.sh"
        ROUTE_HOST=$(oc get route f1-liberty -n f1-tickets-modern \
            --template='{{.spec.host}}' 2>/dev/null || echo "<route-pendiente>")
        print_summary_ocp "${ROUTE_HOST}"
        ;;
    --deploy-container)
        print_banner
        bash "${SCRIPTS_DIR}/02-deploy-container.sh" "${2:-f1-liberty:latest}"
        print_summary_container "${2:-f1-liberty:latest}"
        ;;
    *)
        print_banner
        echo "Uso: $0 <modo> [opciones]"
        echo ""
        echo "  Runtime detectado: ${CTR}"
        echo ""
        echo "  Modos disponibles:"
        echo "    --ocp                        Flujo completo en OpenShift (build + deploy)"
        echo "    --container [image_tag]      Flujo completo local (${CTR})"
        echo "    --ocp-build-only             Solo lanza el build en OCP"
        echo "    --build-only [image_tag]     Solo construye la imagen local"
        echo "    --deploy-ocp                 Solo despliega en OCP (imagen ya construida)"
        echo "    --deploy-container [tag]     Solo despliega en contenedor local"
        echo ""
        echo "  Ejemplos:"
        echo "    $0 --ocp"
        echo "    $0 --container"
        echo "    $0 --container f1-liberty:1.0.0"
        echo "    $0 --build-only"
        echo "    $0 --deploy-ocp"
        echo "    $0 --deploy-container f1-liberty:latest"
        echo ""
        exit 1
        ;;
esac
