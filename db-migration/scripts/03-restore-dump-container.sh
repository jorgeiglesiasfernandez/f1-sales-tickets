#!/usr/bin/env bash
# ==============================================================================
# 03-restore-dump-container.sh
#
# PASO 3 (container) — Restaura el dump SQL en la base de datos externa
#                      levantada con compose (Docker Compose o Podman Compose).
#
# Automáticamente detecta podman o docker (podman tiene prioridad).
#
# Qué hace:
#   1. Verifica que el contenedor f1-external-db está running y listo
#   2. Copia el dump al contenedor
#   3. Ejecuta psql para restaurar los datos
#   4. Verifica que las tablas se han creado correctamente
#
# Prerrequisitos:
#   - BD externa levantada:  cd db-migration/container && <compose> up -d
#   - Fichero de dump disponible
#
# Uso:
#   ./03-restore-dump-container.sh <dump_file>
#   Ejemplo: ./03-restore-dump-container.sh ../dumps/f1-legacy-dump-20260101.sql
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
DUMP_FILE="${1:-}"
CONTAINER="f1-external-db"
PGSQL_USER="appuser"
PGSQL_PASSWORD="apppassword"
PGSQL_DB="appdb"

if [[ -z "${DUMP_FILE}" ]]; then
    echo "✗ Uso: $0 <dump_file>"
    echo "  Ejemplo: $0 ../dumps/f1-legacy-dump-20260101.sql"
    exit 1
fi

if [[ ! -f "${DUMP_FILE}" ]]; then
    echo "✗ Fichero no encontrado: ${DUMP_FILE}"
    exit 1
fi

DUMP_SIZE=$(du -sh "${DUMP_FILE}" | cut -f1)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  F1-Tickets — Restauración del dump en BD externa           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Runtime     : ${CTR}"
echo "  Contenedor  : ${CONTAINER}"
echo "  Dump file   : ${DUMP_FILE} (${DUMP_SIZE})"
echo "  DB destino  : ${PGSQL_DB}"
echo ""

# ---------------------------------------------------------------------------
# PASO 1 — Verificar que el contenedor está running
# ---------------------------------------------------------------------------
echo "→ [1/4] Verificando contenedor '${CONTAINER}'..."

if ! ${CTR} inspect "${CONTAINER}" &>/dev/null; then
    echo "✗ El contenedor '${CONTAINER}' no existe."
    echo "  Ejecuta primero: cd container && <compose> up -d"
    exit 1
fi

CONTAINER_STATUS=$(${CTR} inspect "${CONTAINER}" --format '{{.State.Status}}')
if [[ "${CONTAINER_STATUS}" != "running" ]]; then
    echo "  Contenedor en estado '${CONTAINER_STATUS}', arrancando..."
    ${CTR} start "${CONTAINER}"
fi

# Esperar a que PostgreSQL esté listo
echo "  Esperando que PostgreSQL esté listo..."
MAX_WAIT=60; WAITED=0
until ${CTR} exec "${CONTAINER}" pg_isready -U "${PGSQL_USER}" -d "${PGSQL_DB}" &>/dev/null; do
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo "✗ PostgreSQL no respondió en ${MAX_WAIT}s."
        exit 1
    fi
    echo "  … esperando PostgreSQL (${WAITED}s)..."
    sleep 5; WAITED=$((WAITED + 5))
done
echo "✓ PostgreSQL listo."

# ---------------------------------------------------------------------------
# PASO 2 — Copiar el dump al contenedor
# ---------------------------------------------------------------------------
echo "→ [2/4] Copiando dump al contenedor..."
REMOTE_DUMP="/tmp/restore-$(basename "${DUMP_FILE}")"
${CTR} cp "${DUMP_FILE}" "${CONTAINER}:${REMOTE_DUMP}"
echo "✓ Dump copiado a ${REMOTE_DUMP}"

# ---------------------------------------------------------------------------
# PASO 3 — Restaurar el dump
# ---------------------------------------------------------------------------
echo "→ [3/4] Restaurando dump en base de datos '${PGSQL_DB}'..."
echo "  (Puede tardar unos momentos...)"

${CTR} exec -e PGPASSWORD="${PGSQL_PASSWORD}" "${CONTAINER}" \
    psql -U "${PGSQL_USER}" -d "${PGSQL_DB}" \
         -v ON_ERROR_STOP=0 \
         -f "${REMOTE_DUMP}"

# Limpiar fichero temporal
${CTR} exec "${CONTAINER}" rm -f "${REMOTE_DUMP}"
echo "✓ Dump restaurado."

# ---------------------------------------------------------------------------
# PASO 4 — Verificar la restauración
# ---------------------------------------------------------------------------
echo "→ [4/4] Verificando tablas restauradas..."

${CTR} exec -e PGPASSWORD="${PGSQL_PASSWORD}" "${CONTAINER}" \
    psql -U "${PGSQL_USER}" -d "${PGSQL_DB}" -c "
        SELECT table_name,
               pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) AS tamanio
        FROM information_schema.tables
        WHERE table_schema = 'public'
        ORDER BY table_name;
    "

${CTR} exec -e PGPASSWORD="${PGSQL_PASSWORD}" "${CONTAINER}" \
    psql -U "${PGSQL_USER}" -d "${PGSQL_DB}" -c "
        SELECT 'events'         AS tabla, count(*) AS filas FROM events   UNION ALL
        SELECT 'tickets',                 count(*) FROM tickets            UNION ALL
        SELECT 'purchases',               count(*) FROM purchases          UNION ALL
        SELECT 'purchase_tickets',        count(*) FROM purchase_tickets
        ORDER BY tabla;
    "

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓  Restauración completada con éxito                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Conexión local:"
echo "    Host: localhost"
echo "    Port: 5433"
echo "    User: ${PGSQL_USER}"
echo "    DB:   ${PGSQL_DB}"
echo "    URL:  postgresql://appuser:apppassword@localhost:5433/appdb"
echo ""
echo "  Para conectar con psql:"
echo "    ${CTR} exec -it f1-external-db psql -U appuser appdb"
echo "    — o desde host —"
echo "    PGPASSWORD=apppassword psql -h localhost -p 5433 -U appuser appdb"
echo ""
