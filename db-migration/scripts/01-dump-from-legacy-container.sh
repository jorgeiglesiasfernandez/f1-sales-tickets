#!/usr/bin/env bash
# ==============================================================================
# 01-dump-from-legacy-container.sh
#
# PASO 1 (container) — Parada controlada, extracción del dump y rearranque del
#                      contenedor legacy (Docker o Podman).
#
# Automáticamente detecta podman o docker (podman tiene prioridad).
#
# Qué hace:
#   1. Detecta el contenedor legacy (por nombre o imagen)
#   2. Para el contenedor legacy (ventana de mantenimiento)
#   3. Ejecuta pg_dump arrancando un contenedor temporal con los datos del legacy
#   4. Copia el fichero .sql al directorio local
#   5. Rearrancar el contenedor legacy
#
# Uso:
#   ./01-dump-from-legacy-container.sh [container_name_or_id] [output_dir]
#   Ejemplo:
#     ./01-dump-from-legacy-container.sh f1-tickets ./dumps
#     ./01-dump-from-legacy-container.sh                   # auto-detect
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
# Configuración
# ---------------------------------------------------------------------------
PGSQL_USER="appuser"
PGSQL_PASSWORD="apppassword"
PGSQL_DB="appdb"
PGSQL_DATA="/var/lib/pgsql/15/data"
PG_BIN="/usr/pgsql-15/bin"
DUMP_FILE="f1-legacy-dump-$(date +%Y%m%d-%H%M%S).sql"
OUTPUT_DIR="${2:-./dumps}"

# Auto-detect del contenedor si no se pasa como argumento
if [[ -n "${1:-}" ]]; then
    CONTAINER="${1}"
else
    CONTAINER=$(${CTR} ps --filter "ancestor=f1-sales-tickets" \
                --format "{{.Names}}" 2>/dev/null | head -1 || true)
    if [[ -z "${CONTAINER}" ]]; then
        CONTAINER=$(${CTR} ps --format "{{.Names}}" 2>/dev/null \
                    | grep -i "f1" | head -1 || true)
    fi
fi

if [[ -z "${CONTAINER}" ]]; then
    echo "✗ No se encontró el contenedor legacy."
    echo "  Uso: $0 <container_name_or_id> [output_dir]"
    echo "  Contenedores en ejecución:"
    ${CTR} ps --format "  - {{.Names}} ({{.Image}})"
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  F1-Tickets — Extracción de BD desde contenedor legacy  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Runtime     : ${CTR}"
echo "  Contenedor  : ${CONTAINER}"
echo "  DB          : ${PGSQL_DB}"
echo "  Dump file   : ${OUTPUT_DIR}/${DUMP_FILE}"
echo ""

# Verificar que el contenedor existe
if ! ${CTR} inspect "${CONTAINER}" &>/dev/null; then
    echo "✗ El contenedor '${CONTAINER}' no existe."
    exit 1
fi

# ---------------------------------------------------------------------------
# PASO 1 — Parar el contenedor legacy (parada controlada)
# ---------------------------------------------------------------------------
echo "→ [1/5] Parando el contenedor '${CONTAINER}'..."
${CTR} stop "${CONTAINER}"
echo "✓ Contenedor detenido."

# ---------------------------------------------------------------------------
# PASO 2 — Obtener información de volúmenes del contenedor
# ---------------------------------------------------------------------------
echo "→ [2/5] Obteniendo información de volúmenes del contenedor..."

PG_VOLUME=$(${CTR} inspect "${CONTAINER}" \
    --format '{{range .Mounts}}{{if eq .Destination "/var/lib/pgsql/15/data"}}{{.Name}}{{.Source}}{{end}}{{end}}' \
    2>/dev/null || true)

if [[ -z "${PG_VOLUME}" ]]; then
    PG_VOLUME=$(${CTR} inspect "${CONTAINER}" \
        --format '{{range .Mounts}}{{if eq .Destination "/var/lib/pgsql/15/data"}}{{.Source}}{{end}}{{end}}' \
        2>/dev/null || true)
fi

echo "  Volumen PG detectado: ${PG_VOLUME:-<embebido en contenedor>}"

# ---------------------------------------------------------------------------
# PASO 3 — Ejecutar pg_dump arrancando un contenedor temporal
# ---------------------------------------------------------------------------
echo "→ [3/5] Ejecutando pg_dump (contenedor temporal)..."

DUMP_CONTAINER="f1-db-dump-temp-$$"
ABS_OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

if [[ -n "${PG_VOLUME}" ]]; then
    # Arrancar contenedor temporal postgres:15 con los datos del legacy montados
    ${CTR} run --rm --name "${DUMP_CONTAINER}" \
        -e POSTGRES_USER="${PGSQL_USER}" \
        -e POSTGRES_PASSWORD="${PGSQL_PASSWORD}" \
        -e POSTGRES_DB="${PGSQL_DB}" \
        -e PGDATA="${PGSQL_DATA}" \
        -v "${PG_VOLUME}:${PGSQL_DATA}:Z" \
        -v "${ABS_OUTPUT_DIR}:/dumps:Z" \
        docker.io/library/postgres:15-alpine \
        sh -c "
            chown -R postgres:postgres ${PGSQL_DATA}
            su postgres -s /bin/sh -c '/usr/lib/postgresql/15/bin/pg_ctl -D ${PGSQL_DATA} start -w -t 60'
            PGPASSWORD=${PGSQL_PASSWORD} pg_dump -U ${PGSQL_USER} -d ${PGSQL_DB} > /dumps/${DUMP_FILE}
            su postgres -s /bin/sh -c '/usr/lib/postgresql/15/bin/pg_ctl -D ${PGSQL_DATA} stop'
            echo 'DUMP_OK'
        "
else
    # El PostgreSQL está embebido: usar --volumes-from para acceder a los datos
    ${CTR} run --rm --name "${DUMP_CONTAINER}" \
        --volumes-from "${CONTAINER}" \
        -e PGPASSWORD="${PGSQL_PASSWORD}" \
        -v "${ABS_OUTPUT_DIR}:/dumps:Z" \
        docker.io/library/almalinux:8 \
        bash -c "
            set -e
            chown -R postgres:postgres ${PGSQL_DATA} 2>/dev/null || true
            su -s /bin/bash postgres -c '${PG_BIN}/pg_ctl -D ${PGSQL_DATA} start -w -t 60 -l /tmp/pg.log'
            sleep 2
            su -s /bin/bash postgres -c \
                \"PGPASSWORD=${PGSQL_PASSWORD} ${PG_BIN}/pg_dump \
                  -U ${PGSQL_USER} -d ${PGSQL_DB} -F p\" \
                > /dumps/${DUMP_FILE}
            su -s /bin/bash postgres -c '${PG_BIN}/pg_ctl -D ${PGSQL_DATA} stop'
            echo 'DUMP_OK'
        "
fi

# ---------------------------------------------------------------------------
# PASO 4 — Verificar y reportar el dump
# ---------------------------------------------------------------------------
if [[ -f "${OUTPUT_DIR}/${DUMP_FILE}" ]] && [[ -s "${OUTPUT_DIR}/${DUMP_FILE}" ]]; then
    DUMP_SIZE=$(du -sh "${OUTPUT_DIR}/${DUMP_FILE}" | cut -f1)
    echo "✓ Dump guardado: ${OUTPUT_DIR}/${DUMP_FILE} (${DUMP_SIZE})"
else
    echo "✗ Error: el dump está vacío o no se generó."
    ${CTR} start "${CONTAINER}"
    exit 1
fi

# ---------------------------------------------------------------------------
# PASO 5 — Rearrancar el contenedor legacy
# ---------------------------------------------------------------------------
echo "→ [5/5] Reaarrancando el contenedor legacy '${CONTAINER}'..."
${CTR} start "${CONTAINER}"

# Esperar a que esté healthy (si tiene healthcheck)
MAX_WAIT=60; WAITED=0
while [[ $WAITED -lt $MAX_WAIT ]]; do
    STATUS=$(${CTR} inspect "${CONTAINER}" --format '{{.State.Health.Status}}' 2>/dev/null || echo "none")
    if [[ "${STATUS}" == "healthy" || "${STATUS}" == "none" ]]; then
        break
    fi
    echo "  … esperando contenedor (${STATUS})..."
    sleep 5
    WAITED=$((WAITED + 5))
done
echo "✓ Contenedor legacy reArrancado."

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✓  Extracción completada con éxito                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Fichero de dump: ${OUTPUT_DIR}/${DUMP_FILE}"
echo ""
echo "  Siguiente paso:"
echo "    Container → ./03-restore-dump-container.sh ${OUTPUT_DIR}/${DUMP_FILE}"
echo "    OCP       → ./03-restore-dump-ocp.sh ${OUTPUT_DIR}/${DUMP_FILE}"
echo ""
