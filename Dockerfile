FROM docker.io/library/almalinux:8

LABEL maintainer="local-dev"
LABEL description="Monolito AlmaLinux 8: WildFly 26 + PostgreSQL 15"

# ---------------------------------------------------------------------------
# Variables configurables
# ---------------------------------------------------------------------------
ENV WILDFLY_VERSION=18.0.1.Final \
    WILDFLY_HOME=/opt/wildfly \
    PGSQL_DATA=/var/lib/pgsql/15/data \
    PGSQL_USER=appuser \
    PGSQL_PASSWORD=apppassword \
    PGSQL_DB=appdb \
    PG_JDBC_VERSION=42.5.4 \
    PG_VERSION=15

# ---------------------------------------------------------------------------
# 1. Repositorios — todos públicos, sin suscripción
#    - AlmaLinux BaseOS + AppStream: incluidos por defecto
#    - PGDG: repo oficial de PostgreSQL para EL8 (aarch64)
# ---------------------------------------------------------------------------
RUN dnf install -y \
        https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-aarch64/pgdg-redhat-repo-latest.noarch.rpm \
    && dnf -y module disable postgresql \
    && dnf clean all

# ---------------------------------------------------------------------------
# 2. Dependencias del sistema
# ---------------------------------------------------------------------------
RUN dnf install -y \
        java-1.8.0-openjdk-headless \
        python3 \
        python3-pip \
        curl \
        tar \
        libicu \
    && dnf install -y \
        --disablerepo="*" \
        --enablerepo="pgdg15" \
        postgresql15-server \
        postgresql15 \
    && pip3 install --no-cache-dir supervisor \
    && dnf clean all

# ---------------------------------------------------------------------------
# 3. WildFly
# ---------------------------------------------------------------------------
RUN curl -fsSL \
    "https://download.jboss.org/wildfly/${WILDFLY_VERSION}/wildfly-${WILDFLY_VERSION}.tar.gz" \
    -o /tmp/wildfly.tar.gz \
    && tar xzf /tmp/wildfly.tar.gz -C /opt \
    && ln -s /opt/wildfly-${WILDFLY_VERSION} ${WILDFLY_HOME} \
    && rm /tmp/wildfly.tar.gz

# ---------------------------------------------------------------------------
# 4. Driver JDBC de PostgreSQL como módulo WildFly
# ---------------------------------------------------------------------------
RUN JDBC_JAR="postgresql-${PG_JDBC_VERSION}.jar" \
    && MODULE_DIR="${WILDFLY_HOME}/modules/org/postgresql/main" \
    && mkdir -p "${MODULE_DIR}" \
    && curl -fsSL \
       "https://jdbc.postgresql.org/download/${JDBC_JAR}" \
       -o "${MODULE_DIR}/${JDBC_JAR}" \
    && cat > "${MODULE_DIR}/module.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<module xmlns="urn:jboss:module:1.1" name="org.postgresql">
    <resources>
        <resource-root path="${JDBC_JAR}"/>
    </resources>
    <dependencies>
        <module name="javax.api"/>
        <module name="javax.transaction.api"/>
    </dependencies>
</module>
EOF

# ---------------------------------------------------------------------------
# 5. Configuración de supervisord y scripts
# ---------------------------------------------------------------------------
COPY config/supervisord.conf          /etc/supervisord.conf
COPY config/wildfly-ds.cli            /opt/wildfly-ds.cli
COPY scripts/init-db.sh               /docker-entrypoint-initdb.d/init-db.sh
COPY scripts/sql/01-schema.sql        /docker-entrypoint-initdb.d/01-schema.sql
COPY scripts/sql/02-seed.sql          /docker-entrypoint-initdb.d/02-seed.sql
COPY scripts/entrypoint.sh            /entrypoint.sh
RUN chmod +x /docker-entrypoint-initdb.d/init-db.sh /entrypoint.sh

# ---------------------------------------------------------------------------
# 6. Aplicación — autodeploy al arrancar WildFly
#    Requiere haber ejecutado antes: mvn clean package
# ---------------------------------------------------------------------------
COPY target/f1-sales-tickets.war \
     ${WILDFLY_HOME}/standalone/deployments/f1-sales-tickets.war

# ---------------------------------------------------------------------------
# Puertos expuestos
# 8080 → HTTP app  |  9990 → Admin WildFly  |  5432 → PostgreSQL (dev)
# ---------------------------------------------------------------------------
EXPOSE 8080 9990 5432

ENTRYPOINT ["/entrypoint.sh"]
