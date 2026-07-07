#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Entrypoint: inicializa PostgreSQL (si es la primera vez) y arranca
# supervisord, que gestiona tanto PostgreSQL como WildFly.
# ---------------------------------------------------------------------------
set -euo pipefail

PG_BIN="/usr/pgsql-${PG_VERSION}/bin"
INIT_FLAG="${PGSQL_DATA}/.initialized"

# ---------------------------------------------------------------------------
# 1. Inicializar clúster de PostgreSQL (solo la primera vez)
# ---------------------------------------------------------------------------
# Garantizar permisos correctos siempre (el PVC puede montarse como root en OCP)
mkdir -p "${PGSQL_DATA}"
chown -R postgres:postgres "${PGSQL_DATA}"

if [[ ! -f "${INIT_FLAG}" ]]; then
    echo "→ Inicializando clúster PostgreSQL en ${PGSQL_DATA}..."
    su -s /bin/bash postgres -c "${PG_BIN}/initdb -D ${PGSQL_DATA}"

    # Permitir conexiones locales con contraseña (md5)
    sed -i "s/^#listen_addresses.*/listen_addresses = 'localhost'/" \
        "${PGSQL_DATA}/postgresql.conf"

    # Arrancar PG temporalmente para crear usuario y base de datos
    su -s /bin/bash postgres -c "${PG_BIN}/pg_ctl -D ${PGSQL_DATA} -l /tmp/pg-init.log start"
    sleep 3

    for script in /docker-entrypoint-initdb.d/*.sh; do
        echo "→ Ejecutando ${script}..."
        su -s /bin/bash postgres -c "bash ${script}"
    done

    su -s /bin/bash postgres -c "${PG_BIN}/pg_ctl -D ${PGSQL_DATA} stop"
    touch "${INIT_FLAG}"
    echo "✓ PostgreSQL inicializado."
fi

# ---------------------------------------------------------------------------
# 2. Aplicar configuración de datasource a WildFly (solo la primera vez)
# ---------------------------------------------------------------------------
WILDFLY_FLAG="${WILDFLY_HOME}/.ds-configured"
if [[ ! -f "${WILDFLY_FLAG}" ]]; then
    echo "→ Configurando datasource PostgreSQL en WildFly..."
    # Arrancar WildFly en background para ejecutar el CLI
    "${WILDFLY_HOME}/bin/standalone.sh" \
        -b 0.0.0.0 -bmanagement 0.0.0.0 &
    WF_PID=$!

    # Esperar a que WildFly esté listo
    until "${WILDFLY_HOME}/bin/jboss-cli.sh" \
            --connect --command=":read-attribute(name=server-state)" \
            2>/dev/null | grep -q '"result" => "running"'; do
        echo "  … esperando WildFly..."
        sleep 3
    done

    "${WILDFLY_HOME}/bin/jboss-cli.sh" \
        --connect \
        --file=/opt/wildfly-ds.cli

    "${WILDFLY_HOME}/bin/jboss-cli.sh" --connect --command=":shutdown"
    wait "${WF_PID}" 2>/dev/null || true
    touch "${WILDFLY_FLAG}"
    echo "✓ Datasource configurado."
fi

# ---------------------------------------------------------------------------
# 3. Lanzar supervisord (gestiona PG + WildFly permanentemente)
# ---------------------------------------------------------------------------
echo "→ Arrancando supervisord..."
exec /usr/local/bin/supervisord -c /etc/supervisord.conf
