#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# simulate-purchases-wave2.sh — Wave 2 de compras simuladas
#
# Ejecutar DENTRO del contenedor una vez la aplicación está corriendo.
# Vende ~450 entradas adicionales sobre las ~300 ya vendidas en el arranque,
# dejando el evento con ~750 de 1000 entradas vendidas.
#
#   · 400 GENERAL  (tickets TKT-0251..TKT-0650)
#   ·  50 VIP      (tickets TKT-V051..TKT-V100)
#
# Uso:
#   podman exec -it f1-tickets bash /scripts/simulate-purchases-wave2.sh
#   oc exec -n f1-tickets <pod> -- bash /scripts/simulate-purchases-wave2.sh
# -----------------------------------------------------------------------------
set -euo pipefail

: "${PGSQL_USER:=appuser}"
: "${PGSQL_PASSWORD:=apppassword}"
: "${PGSQL_DB:=appdb}"

PSQL="psql -v ON_ERROR_STOP=1 --username ${PGSQL_USER} --dbname ${PGSQL_DB}"

echo "============================================================"
echo " simulate-purchases-wave2.sh"
echo " Simulando ~450 ventas adicionales (400 GENERAL + 50 VIP)"
echo "============================================================"

# Verificar estado actual
VENDIDAS=$(${PSQL} -tAc "SELECT entradas_vendidas FROM events WHERE id='F1-2026-ESP';")
echo " Entradas vendidas antes: ${VENDIDAS} / 1000"
echo ""

# -----------------------------------------------------------------------------
# 1. Compras GENERAL — 80 compradores × 5 entradas = 400 entradas
#    Tickets TKT-0251..TKT-0650
# -----------------------------------------------------------------------------
echo "→ Insertando 80 compras GENERAL (tickets 251–650)..."

${PSQL} <<'SQL'
INSERT INTO purchases (
    id, event_id, nombre_comprador, email, telefono,
    cantidad_entradas, tipo_entrada, precio_total,
    fecha_compra, estado, codigo_confirmacion
)
SELECT
    'PUR-W2-G' || LPAD(n::text, 3, '0'),
    'F1-2026-ESP',
    (ARRAY[
        'Alfonso Mora','Blanca Serrano','César Herrero','Diana Vega','Ernesto Calvo',
        'Fátima Benito','Gregorio Soto','Helena Arias','Ignacio Luna','Julia Méndez',
        'Kevin Bravo','Leire Gallego','Manuel Rojas','Nadia Fuentes','Omar Pascual',
        'Paloma Crespo','Quintín Lozano','Rebeca Nieto','Salvador Moya','Tamara Rubio',
        'Ulises Pardo','Valentina Cruz','Walter Reina','Ximena Agudo','Yolanda Pedraza',
        'Zacarías Baena','Adrián Segura','Beatriz Montes','Carlos Espinosa','Dolores Toro',
        'Eduardo Mena','Francisca Bernal','Guillermo Tejada','Hortensia Plata','Íñigo Vélez',
        'Jacinta Barrera','Lamberto Cano','Milagros Ríos','Narciso Bosch','Olga Camacho',
        'Patricio Guzmán','Queralt Roca','Rosario Cuenca','Santiago Varela','Trinidad Soler',
        'Ubaldo Marín','Virtudes Palacios','Wilfredo Ojeda','Xenia Montoya','Yago Aranda',
        'Zoraida Casas','Abel Córdoba','Bibiana Esteve','Camilo Solano','Delia Pizarro',
        'Emigdio Tapia','Fernanda Acosta','Gilberto Fuenmayor','Herminia Zárate','Isidro Ponce',
        'Josefa Linares','Klarissa Ibáñez','Leandro Quintero','Macaria Salazar','Norberto Ovalle',
        'Odilia Bermúdez','Primitivo Chacón','Rosalba Fajardo','Timoteo Granados','Ursula Henao',
        'Vidal Jaramillo','Wenceslao Londoño','Xiomara Meza','Yasmin Narváez','Zósimo Ospina',
        'Amelia Pineda','Bonifacio Quiroga','Catalina Restrepo','Donato Sandoval','Evangelina Tobón'
    ])[n],
    'wave2.g' || n || '@email.com',
    '6' || LPAD((30000000 + n * 11)::text, 8, '0'),
    5,
    'GENERAL',
    750.00,
    CURRENT_TIMESTAMP - (interval '1 hour' * (80 - n)),
    'CONFIRMADA',
    'CONF-W2-G' || LPAD(n::text, 3, '0')
FROM generate_series(1, 80) AS n
ON CONFLICT (id) DO NOTHING;

UPDATE tickets SET disponible = FALSE
WHERE id IN (
    SELECT 'TKT-' || LPAD(n::text, 4, '0')
    FROM generate_series(251, 650) AS n
)
AND disponible = TRUE;

INSERT INTO purchase_tickets (purchase_id, ticket_id)
SELECT
    'PUR-W2-G' || LPAD(compra::text, 3, '0'),
    'TKT-' || LPAD((250 + (compra - 1) * 5 + asiento)::text, 4, '0')
FROM
    generate_series(1, 80) AS compra,
    generate_series(1, 5)  AS asiento
ON CONFLICT DO NOTHING;
SQL

echo "✓ Compras GENERAL wave 2 insertadas."

# -----------------------------------------------------------------------------
# 2. Compras VIP — 10 compradores × 5 entradas = 50 entradas
#    Tickets TKT-V051..TKT-V100
# -----------------------------------------------------------------------------
echo "→ Insertando 10 compras VIP (tickets V051–V100)..."

${PSQL} <<'SQL'
INSERT INTO purchases (
    id, event_id, nombre_comprador, email, telefono,
    cantidad_entradas, tipo_entrada, precio_total,
    fecha_compra, estado, codigo_confirmacion
)
SELECT
    'PUR-W2-V' || LPAD(n::text, 3, '0'),
    'F1-2026-ESP',
    (ARRAY[
        'Augusto Ballester','Brunilda Fuster','Casimiro Alemany','Desamparados Moll',
        'Epifanio Sastre','Florentina Colom','Gumersindo Esteve','Honoria Ferragut',
        'Ildefonso Alomar','Joaquina Bonet'
    ])[n],
    'wave2.vip' || n || '@premium.com',
    '6' || LPAD((40000000 + n * 17)::text, 8, '0'),
    5,
    'VIP',
    2250.00,
    CURRENT_TIMESTAMP - (interval '30 minutes' * (10 - n)),
    'CONFIRMADA',
    'CONF-W2-V' || LPAD(n::text, 3, '0')
FROM generate_series(1, 10) AS n
ON CONFLICT (id) DO NOTHING;

UPDATE tickets SET disponible = FALSE
WHERE id IN (
    SELECT 'TKT-V' || LPAD(n::text, 3, '0')
    FROM generate_series(51, 100) AS n
)
AND disponible = TRUE;

INSERT INTO purchase_tickets (purchase_id, ticket_id)
SELECT
    'PUR-W2-V' || LPAD(compra::text, 3, '0'),
    'TKT-V' || LPAD((50 + (compra - 1) * 5 + asiento)::text, 3, '0')
FROM
    generate_series(1, 10) AS compra,
    generate_series(1, 5)  AS asiento
ON CONFLICT DO NOTHING;
SQL

echo "✓ Compras VIP wave 2 insertadas."

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
# 4. Resumen
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Resumen tras wave 2"
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
echo "============================================================"
