-- ---------------------------------------------------------------------------
-- Schema: F1 Sales Tickets
-- Base de datos: PostgreSQL 15
-- ---------------------------------------------------------------------------

-- Tabla de eventos F1
CREATE TABLE IF NOT EXISTS events (
    id                VARCHAR(50)     PRIMARY KEY,
    nombre            VARCHAR(200)    NOT NULL,
    fecha             TIMESTAMP       NOT NULL,
    circuito          VARCHAR(200)    NOT NULL,
    ubicacion         VARCHAR(200)    NOT NULL,
    capacidad_total   INTEGER         NOT NULL DEFAULT 1000,
    entradas_vendidas INTEGER         NOT NULL DEFAULT 0,
    descripcion       TEXT,
    CONSTRAINT chk_entradas CHECK (entradas_vendidas >= 0 AND entradas_vendidas <= capacidad_total)
);

-- Tabla de tickets individuales
CREATE TABLE IF NOT EXISTS tickets (
    id          VARCHAR(50)     PRIMARY KEY,
    event_id    VARCHAR(50)     NOT NULL REFERENCES events(id),
    tipo        VARCHAR(20)     NOT NULL CHECK (tipo IN ('GENERAL', 'VIP')),
    precio      NUMERIC(10, 2)  NOT NULL,
    asiento     VARCHAR(20)     NOT NULL,
    seccion     VARCHAR(20)     NOT NULL,
    disponible  BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_ticket_asiento UNIQUE (event_id, asiento)
);

-- Tabla de compras
CREATE TABLE IF NOT EXISTS purchases (
    id                   VARCHAR(100)    PRIMARY KEY,
    event_id             VARCHAR(50)     NOT NULL REFERENCES events(id),
    nombre_comprador     VARCHAR(200)    NOT NULL,
    email                VARCHAR(200)    NOT NULL,
    telefono             VARCHAR(50),
    cantidad_entradas    INTEGER         NOT NULL CHECK (cantidad_entradas > 0),
    tipo_entrada         VARCHAR(20)     NOT NULL CHECK (tipo_entrada IN ('GENERAL', 'VIP')),
    precio_total         NUMERIC(12, 2)  NOT NULL,
    fecha_compra         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado               VARCHAR(20)     NOT NULL DEFAULT 'PENDIENTE'
                             CHECK (estado IN ('PENDIENTE', 'CONFIRMADA', 'CANCELADA')),
    codigo_confirmacion  VARCHAR(100)
);

-- Tabla de relación compra-tickets
CREATE TABLE IF NOT EXISTS purchase_tickets (
    purchase_id  VARCHAR(100)  NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    ticket_id    VARCHAR(50)   NOT NULL REFERENCES tickets(id),
    PRIMARY KEY (purchase_id, ticket_id)
);

-- Índices para mejorar rendimiento de queries frecuentes
CREATE INDEX IF NOT EXISTS idx_tickets_event_tipo_disponible
    ON tickets (event_id, tipo, disponible);

CREATE INDEX IF NOT EXISTS idx_purchases_event_id
    ON purchases (event_id);

CREATE INDEX IF NOT EXISTS idx_purchases_email
    ON purchases (email);

CREATE INDEX IF NOT EXISTS idx_purchases_estado
    ON purchases (estado);

CREATE INDEX IF NOT EXISTS idx_purchase_tickets_purchase
    ON purchase_tickets (purchase_id);
