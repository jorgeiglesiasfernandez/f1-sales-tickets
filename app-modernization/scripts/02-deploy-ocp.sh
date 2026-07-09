#!/usr/bin/env bash
# ==============================================================================
# 02-deploy-ocp.sh
#
# PASO 2 (OCP) — Despliega la aplicación Liberty modernizada en OpenShift
#                en el namespace f1-tickets-modern.
#
# Qué hace:
#   1. Verifica que el Deployment Liberty está en marcha (post-build)
#   2. Verifica que la BD externa (f1-tickets-db) es accesible desde el cluster
#   3. Aplica el manifiesto de despliegue si aún no existe
#   4. Espera a que el rollout se complete
#   5. Verifica el estado de la aplicación y muestra la URL de acceso
#
# Prerrequisitos:
#   - oc CLI con sesión activa
#   - Build completado: ./01-build-image-ocp.sh
#   - BD externa desplegada en f1-tickets-db:
#     cd ../../db-migration && oc apply -f ocp/deploy-external-db-ocp.yaml
#
# Uso:
#   ./02-deploy-ocp.sh
# ==============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------
NAMESPACE="f1-tickets-modern"
DEPLOYMENT="f1-liberty"
DB_NAMESPACE="f1-tickets-db"
DB_DEPLOYMENT="f1-external-db"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/../ocp/deploy-liberty-ocp.yaml"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  F1-Tickets — Despliegue Liberty modernizado en OCP          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Namespace    : ${NAMESPACE}"
echo "  Deployment   : ${DEPLOYMENT}"
echo "  BD externa   : ${DB_DEPLOYMENT} (${DB_NAMESPACE})"
echo ""

# ---------------------------------------------------------------------------
# PASO 1 — Verificar sesión oc
# ---------------------------------------------------------------------------
echo "→ [1/5] Verificando sesión OCP..."

if ! oc whoami &>/dev/null; then
    echo "✗ No hay sesión oc activa. Ejecuta: oc login <cluster>"
    exit 1
fi
echo "  Usuario OCP  : $(oc whoami)"

# ---------------------------------------------------------------------------
# PASO 2 — Verificar que la BD externa está desplegada y lista
# ---------------------------------------------------------------------------
echo "→ [2/5] Verificando BD externa en namespace '${DB_NAMESPACE}'..."

if ! oc get deployment "${DB_DEPLOYMENT}" -n "${DB_NAMESPACE}" &>/dev/null; then
    echo "✗ La BD externa '${DB_DEPLOYMENT}' no está desplegada en ${DB_NAMESPACE}."
    echo "  Despliégala primero:"
    echo "    cd ../../db-migration"
    echo "    oc apply -f ocp/deploy-external-db-ocp.yaml"
    exit 1
fi

DB_READY=$(oc get deployment "${DB_DEPLOYMENT}" -n "${DB_NAMESPACE}" \
    --template='{{.status.readyReplicas}}' 2>/dev/null || echo "0")

if [[ "${DB_READY}" != "1" ]]; then
    echo "  BD externa no lista (readyReplicas=${DB_READY:-0}). Esperando..."
    oc rollout status deployment/"${DB_DEPLOYMENT}" -n "${DB_NAMESPACE}" --timeout=120s
fi
echo "✓ BD externa lista: ${DB_DEPLOYMENT} (${DB_NAMESPACE})"

# ---------------------------------------------------------------------------
# PASO 3 — Aplicar manifiestos si el Deployment no existe
# ---------------------------------------------------------------------------
echo "→ [3/5] Verificando/aplicando manifiestos Liberty..."

if ! oc get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" &>/dev/null; then
    echo "  Deployment no encontrado. Aplicando manifiesto..."
    if [[ ! -f "${MANIFEST}" ]]; then
        echo "✗ Manifiesto no encontrado: ${MANIFEST}"
        exit 1
    fi
    oc apply -f "${MANIFEST}"
    echo "✓ Manifiesto aplicado."
else
    echo "✓ Deployment '${DEPLOYMENT}' ya existe en ${NAMESPACE}."
    echo "  Para forzar un nuevo despliegue usa: oc rollout restart deployment/${DEPLOYMENT} -n ${NAMESPACE}"
fi

# ---------------------------------------------------------------------------
# PASO 4 — Esperar a que el rollout se complete
# ---------------------------------------------------------------------------
echo "→ [4/5] Esperando rollout del Deployment '${DEPLOYMENT}'..."

oc rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=300s

READY=$(oc get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" \
    --template='{{.status.readyReplicas}}' 2>/dev/null || echo "0")
echo "✓ Deployment listo. Réplicas activas: ${READY}"

# ---------------------------------------------------------------------------
# PASO 5 — Obtener URL de acceso y verificar la app
# ---------------------------------------------------------------------------
echo "→ [5/5] Obteniendo URL de acceso..."

ROUTE_HOST=$(oc get route "${DEPLOYMENT}" -n "${NAMESPACE}" \
    --template='{{.spec.host}}' 2>/dev/null || echo "")

if [[ -z "${ROUTE_HOST}" ]]; then
    echo "  ⚠ No se encontró la Route '${DEPLOYMENT}' en ${NAMESPACE}."
    echo "  Puede que el manifiesto no la haya creado aún."
else
    APP_URL="https://${ROUTE_HOST}/f1-tickets"
    echo "✓ Route disponible: ${APP_URL}"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓  Despliegue OCP completado con éxito                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Deployment   : ${DEPLOYMENT}"
echo "  Namespace    : ${NAMESPACE}"
echo ""
if [[ -n "${ROUTE_HOST:-}" ]]; then
    echo "  ┌─ URLs de acceso ──────────────────────────────────────────┐"
    echo "  │  Web UI  : https://${ROUTE_HOST}/f1-tickets"
    echo "  │  REST API: https://${ROUTE_HOST}/f1-tickets/api/events"
    echo "  └────────────────────────────────────────────────────────────┘"
    echo ""
fi
echo "  BD externa (interna al cluster):"
echo "    Host: f1-external-db.f1-tickets-db.svc.cluster.local"
echo "    Port: 5432  │  User: appuser  │  DB: appdb"
echo ""
echo "  Comandos útiles:"
echo "    oc logs -f deployment/${DEPLOYMENT} -n ${NAMESPACE}"
echo "    oc get pods -n ${NAMESPACE}"
echo "    oc rollout restart deployment/${DEPLOYMENT} -n ${NAMESPACE}"
echo ""
