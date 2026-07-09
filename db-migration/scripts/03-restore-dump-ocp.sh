#!/usr/bin/env bash
# ==============================================================================
# 03-restore-dump-ocp.sh
#
# PASO 3 (OCP) — Restaura el dump SQL en la base de datos externa ya desplegada
#                en el namespace f1-tickets-db.
#
# Qué hace:
#   1. Verifica que la BD externa está lista (pod running + pg_isready)
#   2. Copia el fichero de dump al pod
#   3. Ejecuta psql para restaurar los datos
#   4. Verifica que las tablas se han creado correctamente
#
# Prerrequisitos:
#   - oc CLI con sesión activa
#   - La BD externa ya desplegada: oc apply -f ocp/deploy-external-db-ocp.yaml
#   - Fichero de dump disponible localmente
#
# Uso:
#   ./03-restore-dump-ocp.sh <dump_file>
#   Ejemplo: ./03-restore-dump-ocp.sh ./dumps/f1-legacy-dump-20260101-120000.sql
# ==============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Argumentos y configuración
# ---------------------------------------------------------------------------
DUMP_FILE="${1:-}"
NAMESPACE="f1-tickets-db"
DEPLOYMENT="f1-external-db"
PGSQL_USER="appuser"
PGSQL_PASSWORD="apppassword"
PGSQL_DB="appdb"

if [[ -z "${DUMP_FILE}" ]]; then
    echo "✗ Uso: $0 <dump_file>"
    echo "  Ejemplo: $0 ./dumps/f1-legacy-dump-20260101-120000.sql"
    exit 1
fi

if [[ ! -f "${DUMP_FILE}" ]]; then
    echo "✗ Fichero no encontrado: ${DUMP_FILE}"
    exit 1
fi

DUMP_SIZE=$(du -sh "${DUMP_FILE}" | cut -f1)

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  F1-Tickets — Restauración del dump en BD externa (OCP) ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Namespace  : ${NAMESPACE}"
echo "  Deployment : ${DEPLOYMENT}"
echo "  Dump file  : ${DUMP_FILE} (${DUMP_SIZE})"
echo "  DB destino : ${PGSQL_DB}"
echo ""

# Verificar sesión oc
if ! oc whoami &>/dev/null; then
    echo "✗ No hay sesión oc activa. Ejecuta: oc login <cluster>"
    exit 1
fi

# ---------------------------------------------------------------------------
# PASO 1 — Esperar a que el pod de la BD externa esté listo
# ---------------------------------------------------------------------------
echo "→ [1/4] Esperando a que el pod '${DEPLOYMENT}' esté listo en ${NAMESPACE}..."

oc rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=180s

DB_POD=$(oc get pods -n "${NAMESPACE}" -l app="${DEPLOYMENT}" \
         --field-selector=status.phase=Running --no-headers \
         -o custom-columns=":metadata.name" | head -1)

if [[ -z "${DB_POD}" ]]; then
    echo "✗ No hay pods Running para '${DEPLOYMENT}' en ${NAMESPACE}."
    exit 1
fi
echo "  Pod: ${DB_POD}"

# Esperar pg_isready
echo "  Verificando que PostgreSQL está listo..."
MAX_WAIT=60
WAITED=0
until oc exec "${DB_POD}" -n "${NAMESPACE}" -- \
        pg_isready -U "${PGSQL_USER}" -d "${PGSQL_DB}" &>/dev/null; do
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo "✗ PostgreSQL no respondió en ${MAX_WAIT}s."
        exit 1
    fi
    echo "  … esperando PostgreSQL..."
    sleep 5
    WAITED=$((WAITED + 5))
done
echo "✓ PostgreSQL listo."

# ---------------------------------------------------------------------------
# PASO 2 — Copiar el dump al pod
# ---------------------------------------------------------------------------
echo "→ [2/4] Copiando dump al pod ${DB_POD}..."
REMOTE_DUMP="/tmp/restore-$(basename "${DUMP_FILE}")"
oc cp "${DUMP_FILE}" "${NAMESPACE}/${DB_POD}:${REMOTE_DUMP}"
echo "✓ Dump copiado a ${REMOTE_DUMP}"

# ---------------------------------------------------------------------------
# PASO 3 — Restaurar el dump (psql)
# ---------------------------------------------------------------------------
echo "→ [3/4] Restaurando dump en base de datos '${PGSQL_DB}'..."
echo "  (Esto puede tardar unos minutos dependiendo del tamaño del dump)"

oc exec "${DB_POD}" -n "${NAMESPACE}" -- \
    bash -c "PGPASSWORD=${PGSQL_PASSWORD} psql \
              -U ${PGSQL_USER} \
              -d ${PGSQL_DB} \
              -v ON_ERROR_STOP=0 \
              -f ${REMOTE_DUMP} \
              2>&1 | tail -20"

# Limpiar fichero temporal en el pod
oc exec "${DB_POD}" -n "${NAMESPACE}" -- rm -f "${REMOTE_DUMP}"
echo "✓ Dump restaurado."

# ---------------------------------------------------------------------------
# PASO 4 — Verificar la restauración
# ---------------------------------------------------------------------------
echo "→ [4/4] Verificando tablas restauradas..."

oc exec "${DB_POD}" -n "${NAMESPACE}" -- \
    bash -c "PGPASSWORD=${PGSQL_PASSWORD} psql \
              -U ${PGSQL_USER} -d ${PGSQL_DB} \
              -c \"
                SELECT
                  table_name,
                  (SELECT count(*) FROM information_schema.columns
                   WHERE table_name = t.table_name
                     AND table_schema = 'public') AS columnas,
                  pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) AS tamanio
                FROM information_schema.tables t
                WHERE table_schema = 'public'
                ORDER BY table_name;
              \" && \\
              PGPASSWORD=${PGSQL_PASSWORD} psql \
              -U ${PGSQL_USER} -d ${PGSQL_DB} \
              -c \"
                SELECT
                  'events'         AS tabla, count(*) AS filas FROM events  UNION ALL
                  SELECT 'tickets',           count(*) FROM tickets          UNION ALL
                  SELECT 'purchases',         count(*) FROM purchases        UNION ALL
                  SELECT 'purchase_tickets',  count(*) FROM purchase_tickets
                ORDER BY tabla;
              \""

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✓  Restauración completada con éxito                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Conexión interna al cluster:"
echo "    Host: f1-external-db.f1-tickets-db.svc.cluster.local"
echo "    Port: 5432"
echo "    User: ${PGSQL_USER}"
echo "    DB:   ${PGSQL_DB}"
echo ""
echo "  Para conectar desde otro namespace añade al Secret de tu app:"
echo "    DATABASE_URL: postgresql://appuser:apppassword@"
echo "                  f1-external-db.f1-tickets-db.svc.cluster.local:5432/appdb"
echo ""
