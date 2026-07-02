#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# simulate-purchases-wave3.sh — Wave 3 de compras simuladas (SOLD OUT)
#
# Ejecutar DENTRO del contenedor después de wave 2.
# Vende las ~250 entradas restantes de las 1000 originales del seed,
# dejando el evento COMPLETAMENTE AGOTADO (1000/1000).
#
#   · 200 GENERAL  (tickets TKT-0651..TKT-0800, últimas de G1-G8)
#   · 100 VIP      (tickets TKT-V101..TKT-V200, resto de V1-V2)
#
# Uso:
#   podman exec -it f1-tickets bash /scripts/simulate-purchases-wave3.sh
#   oc exec -n f1-tickets <pod> -- bash /scripts/simulate-purchases-wave3.sh
# -----------------------------------------------------------------------------
set -euo pipefail

: "${PGSQL_USER:=appuser}"
: "${PGSQL_PASSWORD:=apppassword}"
: "${PGSQL_DB:=appdb}"

PSQL="psql -v ON_ERROR_STOP=1 --username ${PGSQL_USER} --dbname ${PGSQL_DB}"

echo "============================================================"
echo " simulate-purchases-wave3.sh — SOLD OUT"
echo " Agotando las 1000 entradas del evento"
echo "============================================================"

VENDIDAS=$(${PSQL} -tAc "SELECT entradas_vendidas FROM events WHERE id='F1-2026-ESP';")
echo " Entradas vendidas antes: ${VENDIDAS} / 1000"
echo ""

# Guardia: si ya están todas vendidas, no hacer nada
if [ "${VENDIDAS}" -ge 1000 ]; then
    echo "⚠ El evento ya está agotado (${VENDIDAS}/1000). No se insertan más compras."
    exit 0
fi

# -----------------------------------------------------------------------------
# 1. Compras GENERAL — 40 compradores × 5 entradas = 200 entradas
#    Tickets TKT-0651..TKT-0800
# -----------------------------------------------------------------------------
echo "→ Insertando 40 compras GENERAL (tickets 651–800)..."

${PSQL} <<'SQL'
INSERT INTO purchases (
    id, event_id, nombre_comprador, email, telefono,
    cantidad_entradas, tipo_entrada, precio_total,
    fecha_compra, estado, codigo_confirmacion
)
SELECT
    'PUR-W3-G' || LPAD(n::text, 3, '0'),
    'F1-2026-ESP',
    (ARRAY[
        'Abelardo Cifuentes','Benedicta Urrutia','Candelario Peñaranda','Deifilia Zambrano',
        'Eladio Murillo','Felícitas Chávez','Gaudencio Bermejo','Humbelina Alcántara',
        'Ireneo Ballesteros','Jacoba Chinchilla','Ladislao Echevarría','Maravillas Fontecha',
        'Nemesio Guardiola','Obdulia Hurtado','Plácido Izquierdo','Quirino Jaén',
        'Restituta Kardas','Sinforoso Larrañaga','Telesfora Marchena','Urbano Novoa',
        'Valentín Oropeza','Wendy Pacheco','Xifré Quijano','Yolanda Recuero','Zenón Salcedo',
        'Ágata Taboada','Bienvenido Ureña','Celestino Valdés','Diamantina Wendell',
        'Emigdio Ximeño','Filomena Yepes','Gaspar Zapata','Herculano Abad','Inmaculada Becerra',
        'Jenaro Castellano','Lucrecio Días','Macrina Espinoza','Norberto Ferri',
        'Obispo Galán','Primitiva Heras'
    ])[n],
    'wave3.g' || n || '@email.com',
    '6' || LPAD((50000000 + n * 19)::text, 8, '0'),
    5,
    'GENERAL',
    750.00,
    CURRENT_TIMESTAMP - (interval '10 minutes' * (40 - n)),
    'CONFIRMADA',
    'CONF-W3-G' || LPAD(n::text, 3, '0')
FROM generate_series(1, 40) AS n
ON CONFLICT (id) DO NOTHING;

UPDATE tickets SET disponible = FALSE
WHERE id IN (
    SELECT 'TKT-' || LPAD(n::text, 4, '0')
    FROM generate_series(651, 800) AS n
)
AND disponible = TRUE;

INSERT INTO purchase_tickets (purchase_id, ticket_id)
SELECT
    'PUR-W3-G' || LPAD(compra::text, 3, '0'),
    'TKT-' || LPAD((650 + (compra - 1) * 5 + asiento)::text, 4, '0')
FROM
    generate_series(1, 40) AS compra,
    generate_series(1, 5)  AS asiento
ON CONFLICT DO NOTHING;
SQL

echo "✓ Compras GENERAL wave 3 insertadas."

# -----------------------------------------------------------------------------
# 2. Compras VIP — 20 compradores × 5 entradas = 100 entradas
#    Tickets TKT-V101..TKT-V200 (agota V1 y V2 completamente)
# -----------------------------------------------------------------------------
echo "→ Insertando 20 compras VIP (tickets V101–V200)..."

${PSQL} <<'SQL'
INSERT INTO purchases (
    id, event_id, nombre_comprador, email, telefono,
    cantidad_entradas, tipo_entrada, precio_total,
    fecha_compra, estado, codigo_confirmacion
)
SELECT
    'PUR-W3-V' || LPAD(n::text, 3, '0'),
    'F1-2026-ESP',
    (ARRAY[
        'Arcadio Benítez','Brígida Cantero','Calixto Domínguez','Demetria Encinas',
        'Eustaquio Figueroa','Florinda Garrido','Gervasio Hidalgo','Higinia Ibarra',
        'Ireneo Jerez','Jucunda Kepler','Liberato Lago','Marcela Morales',
        'Natalio Ñoño','Obscura Obregón','Pancracio Pareja','Querubín Quirós',
        'Rosendo Riquelme','Serapia Siguenza','Teodolindo Trujillo','Ulderico Ugarte'
    ])[n],
    'wave3.vip' || n || '@premium.com',
    '6' || LPAD((60000000 + n * 23)::text, 8, '0'),
    5,
    'VIP',
    2250.00,
    CURRENT_TIMESTAMP - (interval '5 minutes' * (20 - n)),
    'CONFIRMADA',
    'CONF-W3-V' || LPAD(n::text, 3, '0')
FROM generate_series(1, 20) AS n
ON CONFLICT (id) DO NOTHING;

UPDATE tickets SET disponible = FALSE
WHERE id IN (
    SELECT 'TKT-V' || LPAD(n::text, 3, '0')
    FROM generate_series(101, 200) AS n
)
AND disponible = TRUE;

INSERT INTO purchase_tickets (purchase_id, ticket_id)
SELECT
    'PUR-W3-V' || LPAD(compra::text, 3, '0'),
    'TKT-V' || LPAD((100 + (compra - 1) * 5 + asiento)::text, 3, '0')
FROM
    generate_series(1, 20) AS compra,
    generate_series(1, 5)  AS asiento
ON CONFLICT DO NOTHING;
SQL

echo "✓ Compras VIP wave 3 insertadas."

# -----------------------------------------------------------------------------
# 3. Actualizar contador del evento
# -----------------------------------------------------------------------------
${PSQL} -c "
UPDATE events
SET entradas_vendidas = (
    SELECT COUNT(*) FROM tickets WHERE event_id = 'F1-2026-ESP' AND disponible = FALSE
)
WHERE id = 'F1-2026-ESP';"

# -----------------------------------------------------------------------------
# 4. Resumen final — SOLD OUT
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " *** EVENTO AGOTADO — SOLD OUT ***"
echo "============================================================"
${PSQL} -c "
SELECT
    tipo,
    COUNT(*)                                   AS total,
    COUNT(*) FILTER (WHERE disponible)         AS disponibles,
    COUNT(*) FILTER (WHERE NOT disponible)     AS vendidas
FROM tickets
WHERE event_id = 'F1-2026-ESP'
GROUP BY tipo ORDER BY tipo;"

${PSQL} -c "
SELECT entradas_vendidas || ' / ' || capacidad_total AS progreso
FROM events WHERE id = 'F1-2026-ESP';"

TOTAL_COMPRAS=$(${PSQL} -tAc "SELECT COUNT(*) FROM purchases WHERE event_id='F1-2026-ESP';")
INGRESOS=$(${PSQL} -tAc "SELECT TO_CHAR(SUM(precio_total), 'FM999,999,990.00') FROM purchases WHERE event_id='F1-2026-ESP' AND estado='CONFIRMADA';")
echo " Total compras : ${TOTAL_COMPRAS}"
echo " Ingresos totales: €${INGRESOS}"
echo "============================================================"
