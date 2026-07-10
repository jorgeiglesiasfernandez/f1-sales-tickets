#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# reset-purchases.sh — Resetea todas las compras a 0
#
# Borra todas las compras y libera los tickets, dejando el evento con
# entradas_vendidas = 0 y todos los tickets disponibles de nuevo.
#
# Uso (dentro del contenedor):
#   podman exec -it f1-tickets bash /scripts/reset-purchases.sh
#
# Uso (en host con acceso directo a PostgreSQL):
#   PGSQL_USER=appuser PGSQL_PASSWORD=apppassword PGSQL_DB=appdb \
#     PGSQL_HOST=localhost PGSQL_PORT=5432 ./scripts/reset-purchases.sh
#
# Variables de entorno (con valores por defecto del contenedor):
#   PGSQL_USER     — usuario PostgreSQL    (por defecto: appuser)
#   PGSQL_PASSWORD — contraseña            (por defecto: apppassword)
#   PGSQL_DB       — nombre de la BD       (por defecto: appdb)
#   PGSQL_HOST     — host PostgreSQL        (por defecto: localhost)
#   PGSQL_PORT     — puerto PostgreSQL      (por defecto: 5432)
# -----------------------------------------------------------------------------
set -euo pipefail

: "${PGSQL_USER:=appuser}"
: "${PGSQL_PASSWORD:=apppassword}"
: "${PGSQL_DB:=appdb}"
: "${PGSQL_HOST:=localhost}"
: "${PGSQL_PORT:=5432}"

export PGPASSWORD="${PGSQL_PASSWORD}"

PSQL="psql -v ON_ERROR_STOP=1 \
    --host=${PGSQL_HOST} \
    --port=${PGSQL_PORT} \
    --username=${PGSQL_USER} \
    --dbname=${PGSQL_DB}"

echo "========================================================================"
echo " reset-purchases.sh"
echo " Host : ${PGSQL_HOST}:${PGSQL_PORT}"
echo " BD   : ${PGSQL_DB}"
echo "========================================================================"
echo ""

# --------------------------------------------------------------------------
# Estado actual antes del reset
# --------------------------------------------------------------------------
echo "→ Estado ANTES del reset:"
${PSQL} --tuples-only --no-align -c "
    SELECT
        e.id                                         AS evento,
        e.entradas_vendidas                          AS vendidas,
        e.capacidad_total                            AS capacidad,
        (SELECT COUNT(*) FROM purchases p WHERE p.event_id = e.id)   AS compras,
        (SELECT COUNT(*) FROM tickets   t WHERE t.event_id = e.id
                                           AND t.disponible = FALSE)  AS tickets_bloqueados
    FROM events e;
" | column -t -s '|' || true
echo ""

# --------------------------------------------------------------------------
# Reset en una única transacción atómica
# --------------------------------------------------------------------------
echo "→ Ejecutando reset..."
${PSQL} <<-'EOF'
BEGIN;

-- 1. Borrar relaciones compra-ticket (ON DELETE CASCADE las elimina
--    automáticamente al borrar purchases, pero lo hacemos explícito
--    para claridad y para cubrir el caso de que CASCADE no esté activo)
DELETE FROM purchase_tickets;

-- 2. Borrar todas las compras
DELETE FROM purchases;

-- 3. Liberar todos los tickets
UPDATE tickets SET disponible = TRUE WHERE disponible = FALSE;

-- 4. Resetear el contador del evento
UPDATE events SET entradas_vendidas = 0;

COMMIT;
EOF

echo "✓ Reset completado."
echo ""

# --------------------------------------------------------------------------
# Estado final después del reset
# --------------------------------------------------------------------------
echo "→ Estado DESPUÉS del reset:"
${PSQL} --tuples-only --no-align -c "
    SELECT
        e.id                                          AS evento,
        e.entradas_vendidas                           AS vendidas,
        e.capacidad_total                             AS capacidad,
        (SELECT COUNT(*) FROM purchases p WHERE p.event_id = e.id)   AS compras,
        (SELECT COUNT(*) FROM tickets   t WHERE t.event_id = e.id
                                           AND t.disponible = TRUE)   AS tickets_libres
    FROM events e;
" | column -t -s '|' || true
echo ""
echo "========================================================================"
echo " ✓ Todas las compras han sido eliminadas."
echo "   Tickets disponibles: restaurados al total del aforo."
echo "   Entradas vendidas  : 0"
echo "========================================================================"
