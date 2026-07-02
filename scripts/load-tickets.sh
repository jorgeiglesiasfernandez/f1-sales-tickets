#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# load-tickets.sh — Carga tickets adicionales en la BD desde dentro del contenedor
#
# Uso:
#   ./scripts/load-tickets.sh
#
# Añade:
#   - 48  entradas VIP     (secciones V3..V4, 24 asientos cada una)
#   - 167 entradas GENERAL (secciones G9..G16, 20 asientos por sección + 7 en G17)
#
# Los IDs y asientos usan rangos distintos a los del seed inicial para evitar
# conflictos. El script es idempotente: volver a ejecutarlo no duplica datos
# (ON CONFLICT DO NOTHING).
# -----------------------------------------------------------------------------
set -euo pipefail

: "${PGSQL_USER:=appuser}"
: "${PGSQL_PASSWORD:=apppassword}"
: "${PGSQL_DB:=appdb}"

PSQL="psql -v ON_ERROR_STOP=1 --username ${PGSQL_USER} --dbname ${PGSQL_DB}"

echo "============================================================"
echo " load-tickets.sh"
echo " Usuario  : ${PGSQL_USER}"
echo " Base datos: ${PGSQL_DB}"
echo "============================================================"

# -----------------------------------------------------------------------------
# 1. Verificar que el evento existe
# -----------------------------------------------------------------------------
EVENT_EXISTS=$(psql --username "${PGSQL_USER}" --dbname "${PGSQL_DB}" -tAc \
    "SELECT COUNT(*) FROM events WHERE id = 'F1-2026-ESP';")

if [ "${EVENT_EXISTS}" = "0" ]; then
    echo "✗ El evento 'F1-2026-ESP' no existe. Ejecuta primero init-db.sh."
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. Tickets VIP — 48 asientos
#    Secciones V3 y V4, 24 asientos por sección (filas A-D, 6 asientos/fila)
#    IDs: TKT-V201 .. TKT-V248
#    Precio: 450.00
# -----------------------------------------------------------------------------
echo ""
echo "→ Cargando 48 entradas VIP (secciones V3, V4)..."

${PSQL} <<'SQL'
INSERT INTO tickets (id, event_id, tipo, precio, asiento, seccion, disponible)
SELECT
    'TKT-V' || LPAD((200 + num)::text, 3, '0'),
    'F1-2026-ESP',
    'VIP',
    450.00,
    'V' || seccion || '-' || CHR(64 + fila) || LPAD(asiento_num::text, 2, '0'),
    'V' || seccion,
    TRUE
FROM (
    SELECT
        (seccion - 1) * 24 + (fila - 1) * 6 + asiento_num AS num,
        seccion + 2                                         AS seccion,   -- V3, V4
        fila,
        asiento_num
    FROM
        generate_series(1, 2) AS seccion,     -- 2 secciones
        generate_series(1, 4) AS fila,        -- 4 filas (A-D)
        generate_series(1, 6) AS asiento_num  -- 6 asientos por fila
) sub
ON CONFLICT (event_id, asiento) DO NOTHING;
SQL

VIP_INS=$(${PSQL} -tAc "SELECT COUNT(*) FROM tickets WHERE tipo='VIP' AND seccion IN ('V3','V4') AND event_id='F1-2026-ESP';")
echo "✓ Entradas VIP en V3/V4: ${VIP_INS}"

# -----------------------------------------------------------------------------
# 3. Tickets GENERAL — 167 asientos
#    Secciones G9..G16: 20 asientos cada una (filas A-D, 5 asientos/fila) = 160
#    Sección G17: 7 asientos (fila A, asientos 01-07)
#    IDs: TKT-0801 .. TKT-0967
#    Precio: 150.00
# -----------------------------------------------------------------------------
echo ""
echo "→ Cargando 160 entradas GENERAL (secciones G9..G16)..."

${PSQL} <<'SQL'
INSERT INTO tickets (id, event_id, tipo, precio, asiento, seccion, disponible)
SELECT
    'TKT-' || LPAD((800 + num)::text, 4, '0'),
    'F1-2026-ESP',
    'GENERAL',
    150.00,
    'G' || seccion || '-' || CHR(64 + fila) || LPAD(asiento_num::text, 2, '0'),
    'G' || seccion,
    TRUE
FROM (
    SELECT
        (seccion - 1) * 20 + (fila - 1) * 5 + asiento_num AS num,
        seccion + 8                                         AS seccion,   -- G9..G16
        fila,
        asiento_num
    FROM
        generate_series(1, 8) AS seccion,     -- 8 secciones
        generate_series(1, 4) AS fila,        -- 4 filas (A-D)
        generate_series(1, 5) AS asiento_num  -- 5 asientos por fila
) sub
ON CONFLICT (event_id, asiento) DO NOTHING;
SQL

echo "→ Cargando 7 entradas GENERAL (sección G17, fila A)..."

${PSQL} <<'SQL'
INSERT INTO tickets (id, event_id, tipo, precio, asiento, seccion, disponible)
SELECT
    'TKT-' || LPAD((960 + asiento_num)::text, 4, '0'),
    'F1-2026-ESP',
    'GENERAL',
    150.00,
    'G17-A' || LPAD(asiento_num::text, 2, '0'),
    'G17',
    TRUE
FROM generate_series(1, 7) AS asiento_num
ON CONFLICT (event_id, asiento) DO NOTHING;
SQL

GEN_INS=$(${PSQL} -tAc "SELECT COUNT(*) FROM tickets WHERE tipo='GENERAL' AND seccion IN ('G9','G10','G11','G12','G13','G14','G15','G16','G17') AND event_id='F1-2026-ESP';")
echo "✓ Entradas GENERAL en G9..G17: ${GEN_INS}"

# -----------------------------------------------------------------------------
# 4. Actualizar capacidad del evento
# -----------------------------------------------------------------------------
echo ""
echo "→ Actualizando capacidad_total del evento..."

${PSQL} <<'SQL'
UPDATE events
SET capacidad_total = (SELECT COUNT(*) FROM tickets WHERE event_id = 'F1-2026-ESP')
WHERE id = 'F1-2026-ESP';
SQL

TOTAL=$(${PSQL} -tAc "SELECT capacidad_total FROM events WHERE id='F1-2026-ESP';")
echo "✓ capacidad_total actualizada a ${TOTAL} entradas."

# -----------------------------------------------------------------------------
# 5. Resumen final
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Resumen de tickets en 'F1-2026-ESP'"
echo "============================================================"
${PSQL} -c "
SELECT
    tipo,
    COUNT(*)        AS total,
    COUNT(*) FILTER (WHERE disponible)  AS disponibles,
    COUNT(*) FILTER (WHERE NOT disponible) AS vendidas
FROM tickets
WHERE event_id = 'F1-2026-ESP'
GROUP BY tipo
ORDER BY tipo;
"
echo "============================================================"
