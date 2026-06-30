#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy.sh — Construye y despliega f1-sales-tickets.war en WildFly
#
# Uso:
#   ./scripts/deploy.sh                     # build + deploy al contenedor activo
#   ./scripts/deploy.sh --skip-build        # solo despliega (usa WAR ya existente)
#   ./scripts/deploy.sh --container myname  # especifica nombre del contenedor
#   ./scripts/deploy.sh --host 1.2.3.4      # despliega a host remoto vía CLI
# ---------------------------------------------------------------------------
set -euo pipefail

# ---------------------------------------------------------------------------
# Valores por defecto (sobreescribibles por argumentos o variables de entorno)
# ---------------------------------------------------------------------------
SKIP_BUILD=false
CONTAINER_NAME="${CONTAINER_NAME:-almalinux8-dev}"
WILDFLY_HOME="${WILDFLY_HOME:-/opt/wildfly}"
WILDFLY_CLI="${WILDFLY_HOME}/bin/jboss-cli.sh"
MGMT_HOST="${MGMT_HOST:-localhost}"
MGMT_PORT="${MGMT_PORT:-9990}"
WAR_PATH="target/f1-sales-tickets.war"
APP_NAME="f1-sales-tickets"

# ---------------------------------------------------------------------------
# Parseo de argumentos
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build)   SKIP_BUILD=true ;;
        --container)    CONTAINER_NAME="$2"; shift ;;
        --host)         MGMT_HOST="$2"; shift ;;
        --port)         MGMT_PORT="$2"; shift ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# 1. Build Maven (a menos que se indique --skip-build)
# ---------------------------------------------------------------------------
if [[ "${SKIP_BUILD}" == "false" ]]; then
    echo "▶ Construyendo WAR con Maven..."
    mvn clean package -q
    echo "✓ Build completado: ${WAR_PATH} ($(du -sh "${WAR_PATH}" | cut -f1))"
else
    echo "⏭ Build omitido (--skip-build)"
fi

if [[ ! -f "${WAR_PATH}" ]]; then
    echo "✗ No se encontró el WAR en ${WAR_PATH}. Ejecuta sin --skip-build."
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Verificar que el contenedor esté corriendo
# ---------------------------------------------------------------------------
CONTAINER_STATUS=$(podman inspect -f '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "missing")

if [[ "${CONTAINER_STATUS}" == "missing" ]]; then
    echo "✗ El contenedor '${CONTAINER_NAME}' no existe."
    echo "  Ejecútalo primero con:  ./run-podman.sh"
    exit 1
elif [[ "${CONTAINER_STATUS}" != "running" ]]; then
    echo "▶ Contenedor '${CONTAINER_NAME}' detenido — arrancando..."
    podman start "${CONTAINER_NAME}"
    echo "  Esperando a que WildFly esté listo..."
    sleep 20
fi

# ---------------------------------------------------------------------------
# 3. Copiar el WAR al contenedor y desplegarlo vía CLI de WildFly
# ---------------------------------------------------------------------------
echo "▶ Copiando WAR al contenedor '${CONTAINER_NAME}'..."
podman cp "${WAR_PATH}" "${CONTAINER_NAME}:/tmp/${APP_NAME}.war"

echo "▶ Desplegando en WildFly (${MGMT_HOST}:${MGMT_PORT})..."
podman exec "${CONTAINER_NAME}" \
    "${WILDFLY_CLI}" \
    --connect "controller=${MGMT_HOST}:${MGMT_PORT}" \
    --command="deploy /tmp/${APP_NAME}.war --force"

echo ""
echo "✓ Despliegue completado."
echo "  URL de la aplicación: http://localhost:8080/f1-tickets"
echo "  Consola WildFly:      http://localhost:${MGMT_PORT}"
