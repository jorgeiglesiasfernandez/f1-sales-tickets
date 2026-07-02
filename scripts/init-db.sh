#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Crea el usuario, la base de datos y aplica el schema + seed inicial.
# Se ejecuta una sola vez durante la inicialización del clúster.
# ---------------------------------------------------------------------------
set -euo pipefail

echo "→ Creando usuario '${PGSQL_USER}' y base de datos '${PGSQL_DB}'..."

psql -v ON_ERROR_STOP=1 --username postgres <<-EOSQL
    CREATE USER ${PGSQL_USER} WITH PASSWORD '${PGSQL_PASSWORD}';
    CREATE DATABASE ${PGSQL_DB} OWNER ${PGSQL_USER};
    GRANT ALL PRIVILEGES ON DATABASE ${PGSQL_DB} TO ${PGSQL_USER};
EOSQL

echo "✓ Base de datos '${PGSQL_DB}' creada."

echo "→ Aplicando schema..."
psql -v ON_ERROR_STOP=1 --username "${PGSQL_USER}" --dbname "${PGSQL_DB}" \
    -f /docker-entrypoint-initdb.d/01-schema.sql
echo "✓ Schema aplicado."

echo "→ Cargando datos iniciales..."
psql -v ON_ERROR_STOP=1 --username "${PGSQL_USER}" --dbname "${PGSQL_DB}" \
    -f /docker-entrypoint-initdb.d/02-seed.sql
echo "✓ Datos iniciales cargados."

echo "→ Cargando compras simuladas (wave 1)..."
psql -v ON_ERROR_STOP=1 --username "${PGSQL_USER}" --dbname "${PGSQL_DB}" \
    -f /docker-entrypoint-initdb.d/03-purchases-auto.sql
echo "✓ Compras simuladas (wave 1) cargadas."
