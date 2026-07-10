#!/usr/bin/env bash
# ==============================================================================
# deploy/ocp/deploy.sh — Ciclo de vida completo en OpenShift
#
# Gestiona el despliegue de f1-sales-tickets en OCP usando el cliente oc.
# Aplica los manifests de deploy/ocp/manifests/ en orden numérico.
#
# Uso:
#   ./deploy/ocp/deploy.sh apply     — aplica todos los manifests + lanza 1er build
#   ./deploy/ocp/deploy.sh build     — lanza un build manualmente
#   ./deploy/ocp/deploy.sh status    — estado: pods, builds, ruta
#   ./deploy/ocp/deploy.sh logs      — sigue los logs del pod en ejecución
#   ./deploy/ocp/deploy.sh rollout   — fuerza redeploy sin nuevo build
#   ./deploy/ocp/deploy.sh destroy   — elimina el namespace completo
#   ./deploy/ocp/deploy.sh webhook   — muestra la URL del webhook de GitHub
#
# Prerrequisitos:
#   · oc CLI instalado y sesión activa (oc login ...)
#   · kubeadmin para 'apply' y 'destroy' (ClusterRoleBindings)
#   · Reemplazar <STORAGE_CLASSNAME> en manifests/02-storage.yaml antes de 'apply'
# ==============================================================================
set -euo pipefail

NAMESPACE="f1-tickets"
APP="f1-tickets"
# Ruta al directorio de este script (funciona aunque se llame desde cualquier CWD)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"

# ------------------------------------------------------------------------------
# Verificar que oc está disponible y hay sesión activa
# ------------------------------------------------------------------------------
check_oc() {
    if ! command -v oc &>/dev/null; then
        echo "✗ 'oc' no encontrado. Instala el cliente OpenShift CLI." >&2
        echo "  https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/" >&2
        exit 1
    fi
    if ! oc whoami &>/dev/null; then
        echo "✗ No hay sesión activa en OCP." >&2
        echo "  Ejecuta: oc login https://<cluster>:6443 -u <user> -p <pass>" >&2
        exit 1
    fi
    echo "→ Conectado como: $(oc whoami) — cluster: $(oc whoami --show-server)"
}

# ------------------------------------------------------------------------------
# apply — aplica manifests en orden y lanza el primer build
# ------------------------------------------------------------------------------
cmd_apply() {
    check_oc

    # Verificar que no hay placeholder de storage class sin reemplazar
    if grep -q '<STORAGE_CLASSNAME>' "${MANIFESTS_DIR}/02-storage.yaml"; then
        echo ""
        echo "✗ Reemplaza <STORAGE_CLASSNAME> en manifests/02-storage.yaml antes de continuar."
        echo "  Valores habituales:"
        echo "    CRC / local : crc-csi-hostpath-provisioner"
        echo "    OCP / HCP   : kubevirt-csi-infra-default"
        echo ""
        echo "  Ejemplo:"
        echo "    sed -i 's/<STORAGE_CLASSNAME>/crc-csi-hostpath-provisioner/' \\"
        echo "      ${MANIFESTS_DIR}/02-storage.yaml"
        exit 1
    fi

    echo ""
    echo "▶ Aplicando manifests en ${MANIFESTS_DIR}..."
    for manifest in "${MANIFESTS_DIR}"/0*.yaml; do
        echo "  → $(basename "${manifest}")"
        oc apply -f "${manifest}"
    done

    echo ""
    echo "▶ Lanzando primer build..."
    oc start-build "${APP}" -n "${NAMESPACE}" --follow

    echo ""
    echo "▶ Esperando rollout..."
    oc rollout status deployment/"${APP}" -n "${NAMESPACE}"

    echo ""
    cmd_status
}

# ------------------------------------------------------------------------------
# build — lanza un build manualmente y espera a que termine
# ------------------------------------------------------------------------------
cmd_build() {
    check_oc
    echo "▶ Lanzando build de ${APP}..."
    oc start-build "${APP}" -n "${NAMESPACE}" --follow
    echo ""
    echo "▶ Esperando rollout..."
    oc rollout status deployment/"${APP}" -n "${NAMESPACE}"
}

# ------------------------------------------------------------------------------
# status — resumen del estado de la aplicación
# ------------------------------------------------------------------------------
cmd_status() {
    check_oc
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo " Estado: ${APP} — namespace ${NAMESPACE}"
    echo "════════════════════════════════════════════════════════"

    echo ""
    echo "▸ Pods:"
    oc get pods -n "${NAMESPACE}" \
        -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,AGE:.metadata.creationTimestamp' \
        2>/dev/null || echo "  (sin pods)"

    echo ""
    echo "▸ Builds (últimos 3):"
    oc get builds -n "${NAMESPACE}" \
        --sort-by='.metadata.creationTimestamp' 2>/dev/null | tail -4 || echo "  (sin builds)"

    echo ""
    echo "▸ Ruta:"
    ROUTE=$(oc get route "${APP}" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [[ -n "${ROUTE}" ]]; then
        SCHEME="https"
        echo "  URL : ${SCHEME}://${ROUTE}/f1-tickets"
    else
        echo "  (sin ruta)"
    fi
    echo "════════════════════════════════════════════════════════"
}

# ------------------------------------------------------------------------------
# logs — sigue los logs del pod activo
# ------------------------------------------------------------------------------
cmd_logs() {
    check_oc
    echo "→ Siguiendo logs de deployment/${APP} en namespace ${NAMESPACE}..."
    oc logs -f "deployment/${APP}" -n "${NAMESPACE}"
}

# ------------------------------------------------------------------------------
# rollout — fuerza redeploy sin construir nueva imagen
# ------------------------------------------------------------------------------
cmd_rollout() {
    check_oc
    echo "▶ Forzando redeploy de ${APP}..."
    oc rollout restart "deployment/${APP}" -n "${NAMESPACE}"
    oc rollout status "deployment/${APP}" -n "${NAMESPACE}"
}

# ------------------------------------------------------------------------------
# destroy — elimina el namespace completo (irreversible)
# ------------------------------------------------------------------------------
cmd_destroy() {
    check_oc
    echo ""
    echo "⚠  ATENCIÓN: se eliminará el namespace '${NAMESPACE}' y todos sus recursos."
    read -r -p "   Escribe '${NAMESPACE}' para confirmar: " confirm
    if [[ "${confirm}" != "${NAMESPACE}" ]]; then
        echo "Cancelado."
        exit 0
    fi
    oc delete project "${NAMESPACE}"
    # ClusterRoleBindings son cluster-scoped, no se borran al borrar el namespace
    oc delete clusterrolebinding f1-tickets-anyuid  2>/dev/null || true
    oc delete clusterrolebinding f1-webhook-anonymous 2>/dev/null || true
    echo "✓ Namespace y ClusterRoleBindings eliminados."
}

# ------------------------------------------------------------------------------
# webhook — muestra la URL del webhook para configurar en GitHub
# ------------------------------------------------------------------------------
cmd_webhook() {
    check_oc
    echo ""
    echo "▸ URL del webhook Generic para GitHub:"
    oc describe bc/"${APP}" -n "${NAMESPACE}" 2>/dev/null \
        | grep -A3 "Webhook Generic" || echo "  (BuildConfig no encontrado — ejecuta 'apply' primero)"
    echo ""
    echo "▸ Configuración en GitHub:"
    echo "  Payload URL  : URL obtenida arriba"
    echo "  Content-Type : application/json"
    echo "  Secret       : f1ocp2026"
    echo "  Events       : Just the push event"
}

# ------------------------------------------------------------------------------
# Punto de entrada
# ------------------------------------------------------------------------------
case "${1:-}" in
    apply)   cmd_apply ;;
    build)   cmd_build ;;
    status)  cmd_status ;;
    logs)    cmd_logs ;;
    rollout) cmd_rollout ;;
    destroy) cmd_destroy ;;
    webhook) cmd_webhook ;;
    *)
        echo ""
        echo "Uso: $(basename "$0") <comando>"
        echo ""
        echo "Comandos:"
        echo "  apply    — aplicar manifests + lanzar primer build"
        echo "  build    — lanzar build manualmente"
        echo "  status   — estado: pods, builds, ruta"
        echo "  logs     — seguir logs del pod en ejecución"
        echo "  rollout  — forzar redeploy sin nuevo build"
        echo "  destroy  — eliminar namespace completo (pide confirmación)"
        echo "  webhook  — mostrar URL del webhook de GitHub"
        echo ""
        exit 1
        ;;
esac
