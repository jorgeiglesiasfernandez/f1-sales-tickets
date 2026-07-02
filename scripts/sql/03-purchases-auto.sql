-- ---------------------------------------------------------------------------
-- Wave 1 — Compras automáticas al arranque del contenedor
-- Simula ventas previas al despliegue: ~300 entradas vendidas
--   · 250 GENERAL  (tickets TKT-0001..TKT-0250)
--   ·  50 VIP      (tickets TKT-V001..TKT-V050)
-- Todas las compras quedan en estado CONFIRMADA.
-- Idempotente: ON CONFLICT DO NOTHING en purchases y purchase_tickets.
-- ---------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. Compras GENERAL — 50 compradores × 5 entradas = 250 entradas
-- -------------------------------------------------------------------------
INSERT INTO purchases (
    id, event_id, nombre_comprador, email, telefono,
    cantidad_entradas, tipo_entrada, precio_total,
    fecha_compra, estado, codigo_confirmacion
)
SELECT
    'PUR-AUTO-G' || LPAD(n::text, 3, '0'),
    'F1-2026-ESP',
    (ARRAY[
        'Carlos García','María López','Juan Martínez','Ana Fernández','Pedro Sánchez',
        'Laura González','David Torres','Sofía Ramírez','Miguel Díaz','Elena Ruiz',
        'Alejandro Moreno','Isabel Castro','Roberto Jiménez','Carmen Vargas','Francisco Reyes',
        'Patricia Herrera','Antonio Flores','Natalia Romero','Sergio Molina','Cristina Ortega',
        'Fernando Núñez','Beatriz Ramos','Javier Mendoza','Lucía Álvarez','Pablo Gutiérrez',
        'Marta Vázquez','Andrés Delgado','Silvia Peña','Raúl Iglesias','Nuria Medina',
        'Óscar Campos','Verónica Santos','Héctor Guerrero','Adriana Suárez','Enrique Cabrera',
        'Rosa Cano','Alberto Aguilar','Gloria Cruz','Rodrigo Lara','Pilar Rubio',
        'Manuel Carrasco','Inés Navarro','Tomás Serrano','Elena Pardo','Hugo Domínguez',
        'Claudia Gil','Diego Prieto','Lorena Mora','Álvaro Salinas','Teresa Blanco'
    ])[n],
    'comprador' || n || '@email.com',
    '6' || LPAD((10000000 + n * 7)::text, 8, '0'),
    5,
    'GENERAL',
    750.00,
    CURRENT_TIMESTAMP - (interval '1 day' * (60 - n)),
    'CONFIRMADA',
    'CONF-AUTO-G' || LPAD(n::text, 3, '0')
FROM generate_series(1, 50) AS n
ON CONFLICT (id) DO NOTHING;

-- Marcar los 250 tickets GENERAL como vendidos
UPDATE tickets SET disponible = FALSE
WHERE id IN (
    SELECT 'TKT-' || LPAD(n::text, 4, '0')
    FROM generate_series(1, 250) AS n
)
AND disponible = TRUE;

-- Enlazar compras → tickets (5 tickets por compra)
INSERT INTO purchase_tickets (purchase_id, ticket_id)
SELECT
    'PUR-AUTO-G' || LPAD(compra::text, 3, '0'),
    'TKT-' || LPAD(ticket::text, 4, '0')
FROM (
    SELECT
        compra,
        (compra - 1) * 5 + asiento AS ticket
    FROM
        generate_series(1, 50) AS compra,
        generate_series(1, 5)  AS asiento
) t
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------------------------
-- 2. Compras VIP — 10 compradores × 5 entradas = 50 entradas
-- -------------------------------------------------------------------------
INSERT INTO purchases (
    id, event_id, nombre_comprador, email, telefono,
    cantidad_entradas, tipo_entrada, precio_total,
    fecha_compra, estado, codigo_confirmacion
)
SELECT
    'PUR-AUTO-V' || LPAD(n::text, 3, '0'),
    'F1-2026-ESP',
    (ARRAY[
        'Victoria Romero','Emilio Pascual','Sandra Delgado','Marcos Iglesias',
        'Lourdes Fuentes','Gonzalo Vidal','Amparo Nieto','Nicolás Bravo',
        'Concepción Ríos','Esteban Ponce'
    ])[n],
    'vip' || n || '@premium.com',
    '6' || LPAD((20000000 + n * 13)::text, 8, '0'),
    5,
    'VIP',
    2250.00,
    CURRENT_TIMESTAMP - (interval '1 day' * (30 - n)),
    'CONFIRMADA',
    'CONF-AUTO-V' || LPAD(n::text, 3, '0')
FROM generate_series(1, 10) AS n
ON CONFLICT (id) DO NOTHING;

-- Marcar los 50 tickets VIP como vendidos
UPDATE tickets SET disponible = FALSE
WHERE id IN (
    SELECT 'TKT-V' || LPAD(n::text, 3, '0')
    FROM generate_series(1, 50) AS n
)
AND disponible = TRUE;

-- Enlazar compras → tickets
INSERT INTO purchase_tickets (purchase_id, ticket_id)
SELECT
    'PUR-AUTO-V' || LPAD(compra::text, 3, '0'),
    'TKT-V' || LPAD(ticket::text, 3, '0')
FROM (
    SELECT
        compra,
        (compra - 1) * 5 + asiento AS ticket
    FROM
        generate_series(1, 10) AS compra,
        generate_series(1, 5)  AS asiento
) t
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------------------------
-- 3. Actualizar contador de entradas vendidas en el evento
-- -------------------------------------------------------------------------
UPDATE events
SET entradas_vendidas = (
    SELECT COUNT(*) FROM tickets
    WHERE event_id = 'F1-2026-ESP' AND disponible = FALSE
)
WHERE id = 'F1-2026-ESP';
