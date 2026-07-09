#!/usr/bin/env bash
# ==============================================================================
# 02-deploy-container.sh
#
# PASO 2 (container) — Despliega la aplicación Liberty modernizada
#                      en un contenedor local (Docker o Podman).
#
# Automáticamente detecta podman o docker (podman tiene prioridad).
#
# Qué hace:
#   1. Verifica que la imagen Liberty existe localmente
#   2. Verifica que la BD externa (f1-external-db) está disponible
#   3. Arranca el contenedor Liberty conectado a la BD externa
#   4. Espera a que la app responda en el healthcheck
#
# Prerrequisitos:
#   - Imagen Liberty construida: ./01-build-image-container.sh
#   - BD externa disponible:
#     a) Ejecutar migrate-db.sh o
#     b) cd container && <compose> up -d  (desde db-migration/)
#
# Uso:
#   ./02-deploy-container.sh [image_tag]
#   Ejemplo: ./02-deploy-container.sh f1-liberty:latest
# ==============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Detectar runtime: podman tiene prioridad sobre docker
# ---------------------------------------------------------------------------
if command -v podman &>/dev/null; then
    CTR="podman"
elif command -v docker &>/dev/null; then
    CTR="docker"
else
    echo "✗ Neither podman nor docker found. Please install one of them." >&2
    exit 1
fi

echo "→ Using container runtime: ${CTR}"

# ---------------------------------------------------------------------------
# Argumentos y configuración
# ---------------------------------------------------------------------------
IMAGE_TAG="${1:-f1-liberty:latest}"
CONTAINER_NAME="f1-liberty-app"
DB_CONTAINER="f1-external-db"
PGSQL_USER="appuser"
PGSQL_PASSWORD="apppassword"
PGSQL_DB="appdb"
APP_PORT="9080"
APP_PATH="/f1-tickets"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  F1-Tickets — Despliegue Liberty modernizado (container)     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Runtime      : ${CTR}"
echo "  Imagen       : ${IMAGE_TAG}"
echo "  Contenedor   : ${CONTAINER_NAME}"
echo "  BD externa   : ${DB_CONTAINER} (localhost:5433)"
echo "  App URL      : http://localhost:${APP_PORT}${APP_PATH}"
echo ""

# ---------------------------------------------------------------------------
# PASO 1 — Verificar que la imagen Liberty existe
# ---------------------------------------------------------------------------
echo "→ [1/4] Verificando imagen '${IMAGE_TAG}'..."

if ! ${CTR} image inspect "${IMAGE_TAG}" &>/dev/null; then
    echo "✗ Imagen '${IMAGE_TAG}' no encontrada."
    echo "  Construye la imagen primero:"
    echo "    ./01-build-image-container.sh"
    exit 1
fi
echo "✓ Imagen disponible: ${IMAGE_TAG}"

# ---------------------------------------------------------------------------
# PASO 2 — Verificar que la BD externa está running y lista
# ---------------------------------------------------------------------------
echo "→ [2/4] Verificando BD externa '${DB_CONTAINER}'..."

if ! ${CTR} inspect "${DB_CONTAINER}" &>/dev/null; then
    echo "✗ El contenedor '${DB_CONTAINER}' no existe."
    echo "  Levanta la BD externa primero:"
    echo "    cd ../../db-migration && ./migrate-db.sh --restore-container <dump>"
    echo "  — o —"
    echo "    cd container && <compose> up -d"
    exit 1
fi

DB_STATUS=$(${CTR} inspect "${DB_CONTAINER}" --format '{{.State.Status}}')
if [[ "${DB_STATUS}" != "running" ]]; then
    echo "  BD en estado '${DB_STATUS}', arrancando..."
    ${CTR} start "${DB_CONTAINER}"
fi

# Esperar a que PostgreSQL esté listo
echo "  Esperando que PostgreSQL esté listo..."
MAX_WAIT=60; WAITED=0
until ${CTR} exec "${DB_CONTAINER}" pg_isready -U "${PGSQL_USER}" -d "${PGSQL_DB}" &>/dev/null; do
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo "✗ PostgreSQL no respondió en ${MAX_WAIT}s."
        exit 1
    fi
    echo "  … esperando PostgreSQL (${WAITED}s)..."
    sleep 5; WAITED=$((WAITED + 5))
done
echo "✓ BD externa lista."

# ---------------------------------------------------------------------------
# PASO 3 — Arrancar el contenedor Liberty
# ---------------------------------------------------------------------------
echo "→ [3/4] Arrancando contenedor Liberty '${CONTAINER_NAME}'..."

# Si ya existe el contenedor (detenido), arrancarlo; si no, crearlo
if ${CTR} container inspect "${CONTAINER_NAME}" &>/dev/null; then
    echo "  Contenedor existente encontrado, arrancando..."
    ${CTR} start "${CONTAINER_NAME}"
else
    echo "  Creando y arrancando contenedor '${CONTAINER_NAME}'..."
    ${CTR} run -d \
        --name "${CONTAINER_NAME}" \
        -p "${APP_PORT}:9080" \
        -p "9443:9443" \
        -e DB_HOST="${DB_CONTAINER}" \
        -e DB_PORT="5432" \
        -e DB_NAME="${PGSQL_DB}" \
        -e DB_USER="${PGSQL_USER}" \
        -e DB_PASSWORD="${PGSQL_PASSWORD}" \
        --link "${DB_CONTAINER}:${DB_CONTAINER}" \
        "${IMAGE_TAG}"
fi

echo "✓ Contenedor '${CONTAINER_NAME}' iniciado."

# ---------------------------------------------------------------------------
# PASO 4 — Esperar a que la aplicación responda
# ---------------------------------------------------------------------------
echo "→ [4/4] Esperando que la aplicación Liberty esté lista..."

MAX_WAIT=120; WAITED=0
until curl -sf "http://localhost:${APP_PORT}${APP_PATH}" &>/dev/null; do
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo "✗ La aplicación no respondió en ${MAX_WAIT}s."
        echo "  Revisa los logs: ${CTR} logs ${CONTAINER_NAME}"
        exit 1
    fi
    echo "  … esperando Liberty (${WAITED}s)..."
    sleep 10; WAITED=$((WAITED + 10))
done
echo "✓ Aplicación lista."

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓  Despliegue completado con éxito                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Contenedor   : ${CONTAINER_NAME}"
echo "  Runtime       : ${CTR}"
echo ""
echo "  ┌─ URLs de acceso ──────────────────────────────────────────┐"
echo "  │  Web UI  : http://localhost:${APP_PORT}${APP_PATH}                  │"
echo "  │  REST API: http://localhost:${APP_PORT}${APP_PATH}/api/events        │"
echo "  │  HTTPS   : https://localhost:9443${APP_PATH}                │"
echo "  └────────────────────────────────────────────────────────────┘"
echo ""
echo "  BD externa:"
echo "    Host: localhost  │  Port: 5433  │  User: ${PGSQL_USER}  │  DB: ${PGSQL_DB}"
echo ""
echo "  Comandos útiles:"
echo "    ${CTR} logs -f ${CONTAINER_NAME}"
echo "    ${CTR} stop ${CONTAINER_NAME}"
echo "    ${CTR} rm   ${CONTAINER_NAME}"
echo ""
