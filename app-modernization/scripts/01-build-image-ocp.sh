#!/usr/bin/env bash
# ==============================================================================
# 01-build-image-ocp.sh
#
# PASO 1 (OCP) — Lanza un Build en OpenShift para construir la imagen Liberty
#                directamente en el cluster a partir del repositorio Git.
#
# Qué hace:
#   1. Verifica que la sesión oc está activa y el BuildConfig existe
#   2. Inicia el build en el cluster (oc start-build)
#   3. Sigue los logs del build en tiempo real
#   4. Verifica que la imagen ha sido publicada en el ImageStream
#
# Prerrequisitos:
#   - oc CLI con sesión activa
#   - El manifiesto de despliegue ya aplicado:
#     oc apply -f ocp/deploy-liberty-ocp.yaml
#
# Uso:
#   ./01-build-image-ocp.sh
# ==============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------
NAMESPACE="f1-tickets-modern"
BUILD_CONFIG="f1-liberty"
IMAGE_STREAM="f1-liberty"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  F1-Tickets — Build imagen Liberty en OCP                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Namespace    : ${NAMESPACE}"
echo "  BuildConfig  : ${BUILD_CONFIG}"
echo "  ImageStream  : ${IMAGE_STREAM}"
echo ""

# ---------------------------------------------------------------------------
# PASO 1 — Verificar sesión oc y existencia del BuildConfig
# ---------------------------------------------------------------------------
echo "→ [1/4] Verificando sesión OCP y recursos..."

if ! oc whoami &>/dev/null; then
    echo "✗ No hay sesión oc activa. Ejecuta: oc login <cluster>"
    exit 1
fi
echo "  Usuario OCP  : $(oc whoami)"

if ! oc get buildconfig "${BUILD_CONFIG}" -n "${NAMESPACE}" &>/dev/null; then
    echo "✗ BuildConfig '${BUILD_CONFIG}' no encontrado en ${NAMESPACE}."
    echo "  Aplica primero el manifiesto:"
    echo "    oc apply -f ocp/deploy-liberty-ocp.yaml"
    exit 1
fi
echo "✓ BuildConfig '${BUILD_CONFIG}' encontrado."

# ---------------------------------------------------------------------------
# PASO 2 — Iniciar el build
# ---------------------------------------------------------------------------
echo "→ [2/4] Iniciando build en OCP..."

BUILD_NAME=$(oc start-build "${BUILD_CONFIG}" -n "${NAMESPACE}" --output=name)
echo "✓ Build iniciado: ${BUILD_NAME}"

# ---------------------------------------------------------------------------
# PASO 3 — Seguir los logs del build
# ---------------------------------------------------------------------------
echo "→ [3/4] Siguiendo logs del build (esto puede tardar varios minutos)..."
oc logs -f "${BUILD_NAME}" -n "${NAMESPACE}"

# ---------------------------------------------------------------------------
# PASO 4 — Verificar que la imagen fue publicada
# ---------------------------------------------------------------------------
echo "→ [4/4] Verificando imagen en ImageStream '${IMAGE_STREAM}'..."

BUILD_STATUS=$(oc get "${BUILD_NAME}" -n "${NAMESPACE}" \
    --template='{{.status.phase}}' 2>/dev/null || echo "Unknown")

if [[ "${BUILD_STATUS}" != "Complete" ]]; then
    echo "✗ El build terminó con estado '${BUILD_STATUS}'."
    echo "  Revisa los logs: oc logs ${BUILD_NAME} -n ${NAMESPACE}"
    exit 1
fi

IMAGE_TAG=$(oc get imagestream "${IMAGE_STREAM}" -n "${NAMESPACE}" \
    --template='{{range .status.tags}}{{if eq .tag "latest"}}{{(index .items 0).dockerImageReference}}{{end}}{{end}}' \
    2>/dev/null || echo "")

echo "✓ Build completado. Estado: ${BUILD_STATUS}"
[[ -n "${IMAGE_TAG}" ]] && echo "  Imagen en registry: ${IMAGE_TAG}"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓  Build OCP completado con éxito                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  BuildConfig  : ${BUILD_CONFIG}"
echo "  Namespace    : ${NAMESPACE}"
echo ""
echo "  Siguiente paso:"
echo "    OCP → ./02-deploy-ocp.sh"
echo ""
