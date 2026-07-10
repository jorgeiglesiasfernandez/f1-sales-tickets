-- ---------------------------------------------------------------------------
-- Seed: Gran Premio de España F1 2026
-- Evento ID: F1-2026-ESP  |  Capacidad: 1000 (800 GENERAL + 200 VIP)
-- ---------------------------------------------------------------------------

INSERT INTO events (id, nombre, fecha, circuito, ubicacion, capacidad_total, entradas_vendidas, descripcion)
VALUES (
    'F1-2026-ESP',
    'Gran Premio de España 2026',
    '2026-05-24 14:00:00',
    'Circuit de Barcelona-Catalunya',
    'Montmeló, Barcelona, España',
    1000,
    0,
    'El Gran Premio de España de Fórmula 1 2026 en el mítico Circuit de Barcelona-Catalunya. Una de las carreras más emblemáticas del campeonato mundial.'
)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Tickets GENERAL (800 asientos)
-- Secciones: G1..G8, 100 asientos cada una, precio 150.00
-- Formato asiento: G{seccion}-{fila}{num}  (ej. G1-A01)
-- ---------------------------------------------------------------------------
INSERT INTO tickets (id, event_id, tipo, precio, asiento, seccion, disponible)
SELECT
    'TKT-' || LPAD(num::text, 4, '0'),
    'F1-2026-ESP',
    'GENERAL',
    150.00,
    'G' || seccion || '-' || CHR(64 + fila) || LPAD(asiento_num::text, 2, '0'),
    'G' || seccion,
    TRUE
FROM (
    SELECT
        (seccion - 1) * 100 + (fila - 1) * 10 + asiento_num AS num,
        seccion,
        fila,
        asiento_num
    FROM
        generate_series(1, 8)  AS seccion,
        generate_series(1, 10) AS fila,
        generate_series(1, 10) AS asiento_num
) sub
ON CONFLICT (event_id, asiento) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Tickets VIP (200 asientos)
-- Secciones: V1..V2, 100 asientos cada una, precio 450.00
-- Formato asiento: V{seccion}-{fila}{num}  (ej. V1-A01)
-- ---------------------------------------------------------------------------
INSERT INTO tickets (id, event_id, tipo, precio, asiento, seccion, disponible)
SELECT
    'TKT-V' || LPAD(num::text, 3, '0'),
    'F1-2026-ESP',
    'VIP',
    450.00,
    'V' || seccion || '-' || CHR(64 + fila) || LPAD(asiento_num::text, 2, '0'),
    'V' || seccion,
    TRUE
FROM (
    SELECT
        (seccion - 1) * 100 + (fila - 1) * 10 + asiento_num AS num,
        seccion,
        fila,
        asiento_num
    FROM
        generate_series(1, 2)  AS seccion,
        generate_series(1, 10) AS fila,
        generate_series(1, 10) AS asiento_num
) sub
ON CONFLICT (event_id, asiento) DO NOTHING;
