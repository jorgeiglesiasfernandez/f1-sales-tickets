# ===========================================================================
# Stage 1 — Builder: compiles the WAR with Maven
# eclipse-temurin is a multi-arch image (amd64 + arm64) — the build always
# runs on the native architecture of the node performing the build.
# ===========================================================================
FROM docker.io/library/maven:3.9-eclipse-temurin-8 AS builder

WORKDIR /build
COPY pom.xml .
# Download dependencies in a separate layer to leverage Docker cache
RUN mvn dependency:go-offline -q

COPY src/ src/
RUN mvn clean package -q -DskipTests

# ===========================================================================
# Stage 2 — Runtime: AlmaLinux 8 + PostgreSQL 15 + WildFly 18 + supervisord
# TARGETARCH is injected automatically by BuildKit (amd64 / arm64)
# ===========================================================================
FROM docker.io/library/almalinux:8

LABEL maintainer="local-dev"
LABEL description="Monolith AlmaLinux 8: WildFly 18 + PostgreSQL 15"

ARG TARGETARCH

ENV WILDFLY_VERSION=18.0.1.Final \
    WILDFLY_HOME=/opt/wildfly \
    PGSQL_DATA=/var/lib/pgsql/15/data \
    PGSQL_USER=appuser \
    PGSQL_PASSWORD=apppassword \
    PGSQL_DB=appdb \
    PG_JDBC_VERSION=42.5.4 \
    PG_VERSION=15

# ---------------------------------------------------------------------------
# 1. Repositories — PGDG RPM selected based on the node architecture
# ---------------------------------------------------------------------------
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") \
    && dnf install -y --nogpgcheck \
        "https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-${ARCH}/pgdg-redhat-repo-latest.noarch.rpm" \
    && sed -i 's/^gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/pgdg*.repo \
    && sed -i 's/^repo_gpgcheck=1/repo_gpgcheck=0/g' /etc/yum.repos.d/pgdg*.repo \
    && dnf -y module disable postgresql \
    && dnf clean all

# ---------------------------------------------------------------------------
# 2. System dependencies
# Notes on Java:
#   - java-1.8.0-openjdk-headless → Java 8  (class version 52) required by WildFly 18
#   JAVA_HOME keeps pointing to Java 8 so WildFly starts correctly.
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
# 3. WildFly application server
# ---------------------------------------------------------------------------
RUN curl -fsSL \
    "https://download.jboss.org/wildfly/${WILDFLY_VERSION}/wildfly-${WILDFLY_VERSION}.tar.gz" \
    -o /tmp/wildfly.tar.gz \
    && tar xzf /tmp/wildfly.tar.gz -C /opt \
    && ln -s /opt/wildfly-${WILDFLY_VERSION} ${WILDFLY_HOME} \
    && rm /tmp/wildfly.tar.gz

# ---------------------------------------------------------------------------
# 4. PostgreSQL JDBC driver registered as a WildFly module
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
# 5. supervisord config, init scripts and simulation scripts
# ---------------------------------------------------------------------------
COPY config/supervisord.conf          /etc/supervisord.conf
COPY config/wildfly-ds.cli            /opt/wildfly-ds.cli
COPY scripts/init-db.sh               /docker-entrypoint-initdb.d/init-db.sh
COPY scripts/sql/01-schema.sql        /docker-entrypoint-initdb.d/01-schema.sql
COPY scripts/sql/02-seed.sql          /docker-entrypoint-initdb.d/02-seed.sql
# Wave 1 simulated purchases — applied automatically on first boot
COPY scripts/sql/03-purchases-auto.sql /docker-entrypoint-initdb.d/03-purchases-auto.sql
COPY scripts/entrypoint.sh            /entrypoint.sh
# Manual simulation scripts — available inside the container under /scripts/
COPY scripts/load-tickets.sh              /scripts/load-tickets.sh
COPY scripts/simulate-purchases-wave2.sh  /scripts/simulate-purchases-wave2.sh
COPY scripts/simulate-purchases-wave3.sh  /scripts/simulate-purchases-wave3.sh
COPY scripts/simulate-purchases-random.sh /scripts/simulate-purchases-random.sh
RUN chmod +x \
        /docker-entrypoint-initdb.d/init-db.sh \
        /entrypoint.sh \
        /scripts/load-tickets.sh \
        /scripts/simulate-purchases-wave2.sh \
        /scripts/simulate-purchases-wave3.sh \
        /scripts/simulate-purchases-random.sh

# ---------------------------------------------------------------------------
# 6. Application — WAR built in the builder stage
# ---------------------------------------------------------------------------
COPY --from=builder /build/target/f1-sales-tickets.war \
     ${WILDFLY_HOME}/standalone/deployments/f1-sales-tickets.war

# ---------------------------------------------------------------------------
# Exposed ports
# 8080 → HTTP app  |  9990 → WildFly Admin  |  5432 → PostgreSQL (dev)
# ---------------------------------------------------------------------------
EXPOSE 8080 9990 5432

ENTRYPOINT ["/entrypoint.sh"]
