# F1 Sales Tickets

> **Intentional monolith** — designed as a modernisation lab target for Java application re-platforming exercises (WildFly → cloud-native, monolith → microservices).

A ticket-sales web application for the **2026 Spanish Formula 1 Grand Prix**, built with deliberately legacy technology choices: Java 8, Apache Struts 2, JDBC-over-JNDI, and a self-managed PostgreSQL 15 instance co-located inside the same container as the application server.

---

## Purpose

This project simulates a **real-world brownfield monolith** with the following intentional characteristics that make it an ideal candidate for modernisation exercises:

| Characteristic | Detail |
|---|---|
| Runtime | WildFly 18 (Java EE 7) |
| Java version | Java 8 |
| Web framework | Apache Struts 2.5 (MVC, JSP views) |
| Database access | Raw JDBC via JNDI DataSource — no ORM |
| Process manager | `supervisord` co-manages WildFly + PostgreSQL |
| Database | PostgreSQL 15 bundled inside the container |
| Build | Maven WAR packaging |
| Container base | AlmaLinux 8 |

It is particularly suited for practising:

- **Re-platforming** from WildFly/JBoss to **Open Liberty** or **Quarkus**
- **Containerisation** and **OpenShift / Kubernetes** deployment
- **Service extraction** — splitting the monolith into microservices (Events, Tickets, Purchases)
- **Dependency modernisation** — upgrading from Java 8 + Struts 2 to Jakarta EE / Spring Boot

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Container                        │
│                                                     │
│  ┌──────────────┐        ┌──────────────────────┐  │
│  │  supervisord │        │     WildFly 18        │  │
│  │  (PID 1)     │───────▶│  :8080  HTTP          │  │
│  │              │        │  :9990  Admin         │  │
│  │              │        │                       │  │
│  │              │        │  f1-sales-tickets.war │  │
│  │              │        │  ├── Struts 2 (UI)    │  │
│  │              │        │  ├── JAX-RS (REST API)│  │
│  │              │        │  └── JDBC → AppDS     │  │
│  │              │        └──────────┬────────────┘  │
│  │              │                   │ JNDI DataSource│
│  │              │        ┌──────────▼────────────┐  │
│  │              │───────▶│   PostgreSQL 15        │  │
│  └──────────────┘        │   :5432               │  │
│                          └──────────┬────────────┘  │
└─────────────────────────────────────┼───────────────┘
                                      │
                             PersistentVolume
                          /var/lib/pgsql/15/data
```

### Layers inside the WAR

```
com.ticketsales
├── action/          Struts 2 Actions — web UI controllers
│   ├── DashboardAction.java
│   ├── EventAction.java
│   ├── PurchaseAction.java
│   └── TicketAction.java
├── model/           Plain domain objects (Event, Ticket, Purchase)
├── repository/      JDBC repositories — raw SQL, no ORM
├── rest/            JAX-RS REST API (/api/*)
│   ├── EventRestController.java
│   ├── TicketRestController.java
│   └── PurchaseRestController.java
├── dto/             Request/Response DTOs
└── util/            DatabaseConnection helper (JNDI lookup)
```

### Data model

```
events ──< tickets
  │
  └──< purchases ──< purchase_tickets >── tickets
```

| Table | Description |
|---|---|
| `events` | F1 race events (circuit, date, capacity) |
| `tickets` | Individual seats (type: GENERAL / VIP, section, price) |
| `purchases` | Buyer info, quantity, status (PENDIENTE / CONFIRMADA / CANCELADA) |
| `purchase_tickets` | Join table linking purchases to specific ticket seats |

---

## Technology Stack

| Layer | Technology | Version |
|---|---|---|
| Base OS | AlmaLinux | 8 |
| JDK | OpenJDK | 8 |
| Application server | WildFly | 18.0.1.Final |
| Web framework | Apache Struts | 2.5.30 |
| REST API | JAX-RS / RESTEasy | 2.1 / 3.9.1 |
| JSON | Jackson | 2.12.7 |
| Database | PostgreSQL | 15 |
| JDBC driver | postgresql | 42.5.4 |
| Process manager | supervisord | (pip3) |
| Build tool | Maven | 3.9 |
| Container build | Podman / Docker multi-stage | `Containerfile` (OCI/AMA) |

---

## REST API

Base path: `/f1-tickets/api`

### Events

| Method | Path | Description |
|---|---|---|
| `GET` | `/events` | Información del evento activo |
| `GET` | `/events/{id}` | Evento por ID |
| `GET` | `/events/availability` | Disponibilidad global del evento (capacidad, vendidas, % ocupación) |

### Tickets

| Method | Path | Query params | Description |
|---|---|---|---|
| `GET` | `/tickets/available` | `tipo` (GENERAL\|VIP), `limit` | Tickets disponibles (con filtro opcional de tipo) |
| `GET` | `/tickets/availability` | — | Disponibilidad por tipo con precio |
| `GET` | `/tickets/{id}` | — | Detalle de un ticket concreto |
| `GET` | `/tickets/stats` | — | Estadísticas globales (capacidad, vendidos, % ocupación, disponibles por tipo) |
| `POST` | `/tickets` | — | Crea un ticket de forma idempotente (`ON CONFLICT DO NOTHING`) |

**Body `POST /tickets`:**
```json
{
  "eventId":  "F1-2026-ESP",
  "tipo":     "VIP",
  "asiento":  "V3-A01",
  "seccion":  "V3"
}
```

### Purchases

| Method | Path | Query params | Description |
|---|---|---|---|
| `POST` | `/purchases` | — | Crea una nueva compra (reserva tickets + actualiza contador) |
| `GET` | `/purchases` | `email`, `estado`, `limit` (default 50) | Listado de compras con filtros opcionales |
| `GET` | `/purchases/{id}` | — | Compra por ID |
| `GET` | `/purchases/stats` | — | Estadísticas (total compras, ingresos, ventas por tipo, promedio de entradas) |

**Body `POST /purchases`:**
```json
{
  "eventId":         "F1-2026-ESP",
  "nombreComprador": "Carlos Martínez",
  "email":           "carlos@example.com",
  "telefono":        "612345678",
  "cantidadEntradas": 2,
  "tipoEntrada":     "GENERAL"
}
```

> Máximo 10 entradas por transacción. Devuelve `409 Conflict` si no hay stock suficiente.

---

## Multi-stage Container Build

The [`Containerfile`](Containerfile) follows the **IBM AMA / OCI standard** naming convention (`Containerfile` instead of `Dockerfile`) and uses a two-stage build so no local Maven or JDK installation is required:

```
Stage 1 — builder (maven:3.9-eclipse-temurin-8)
  └── mvn clean package → f1-sales-tickets.war

Stage 2 — runtime (almalinux:8)
  ├── Install PostgreSQL 15 (PGDG repo, auto-detects amd64/arm64)
  ├── Install WildFly 18
  ├── Install supervisord
  └── Copy WAR from stage 1
```

The image is **multi-architecture** (`amd64` + `arm64`) — the `TARGETARCH` build argument selects the correct PostgreSQL repository at build time. No separate Containerfile is needed for Apple Silicon or ARM-based nodes.

### OCI Labels (IBM AMA required)

The Containerfile includes standard OCI image labels:

| Label | Value |
|---|---|
| `org.opencontainers.image.title` | `f1-sales-tickets` |
| `org.opencontainers.image.vendor` | `IBM` |
| `org.opencontainers.image.source` | GitHub repository URL |
| `org.opencontainers.image.version` | `1.0.0` |
| `org.opencontainers.image.licenses` | `Apache-2.0` |

---

## Running Locally

[`run-container.sh`](run-container.sh) auto-detects **podman** or **docker** (podman takes priority) and the **native CPU architecture** (`arm64` / `amd64`), passing the correct `--platform` flag automatically. No manual configuration needed on Apple Silicon or x86_64.

### With the helper script (recommended)

```bash
./run-container.sh                # build + run (default)
./run-container.sh build          # build image for native arch only
./run-container.sh run            # start container (create if needed)
./run-container.sh stop           # stop the running container
./run-container.sh logs           # follow container logs
./run-container.sh destroy        # remove container and persistent volume
./run-container.sh multiarch-push # build amd64+arm64 manifest and push to registry
                                  # requires: export IMAGE_REGISTRY=quay.io/myorg
```

### Manual commands

```bash
# Build for native architecture (podman or docker — both use Containerfile)
podman build -f Containerfile -t f1-sales-tickets .
docker build -f Containerfile -t f1-sales-tickets .

# Build targeting a specific platform explicitly
podman build --platform linux/arm64 -f Containerfile -t f1-sales-tickets .
podman build --platform linux/amd64 -f Containerfile -t f1-sales-tickets .

# Run (ephemeral — data is lost when the container is removed)
podman run -d \
  --name f1-tickets \
  -p 8080:8080 \
  -p 9990:9990 \
  -e PGSQL_USER=appuser \
  -e PGSQL_PASSWORD=apppassword \
  -e PGSQL_DB=appdb \
  f1-sales-tickets
```

For **persistent data** across container restarts, mount a named volume on the PostgreSQL data directory:

```bash
# Create the volume once
podman volume create f1-tickets-pgdata

# Run with persistent volume
podman run -d \
  --name f1-tickets \
  -p 8080:8080 \
  -p 9990:9990 \
  -e PGSQL_USER=appuser \
  -e PGSQL_PASSWORD=apppassword \
  -e PGSQL_DB=appdb \
  -v f1-tickets-pgdata:/var/lib/pgsql/15/data \
  f1-sales-tickets
```

> The database is only initialised (schema + seed + wave 1 purchases) on the **first run**, when the volume is empty. Subsequent starts reuse the existing data.

### Multi-arch publish (amd64 + arm64 in a single manifest)

```bash
# With podman
IMAGE_REGISTRY=quay.io/myorg ./run-container.sh multiarch-push

# Manually with podman
podman build --platform linux/amd64,linux/arm64 \
  --manifest quay.io/myorg/f1-sales-tickets:latest \
  -f Containerfile .
podman manifest push quay.io/myorg/f1-sales-tickets:latest \
  docker://quay.io/myorg/f1-sales-tickets:latest

# Manually with docker buildx
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Containerfile \
  -t quay.io/myorg/f1-sales-tickets:latest \
  --push .
```

### Access

| Endpoint | URL |
|---|---|
| Web UI | `http://localhost:8080/f1-tickets` |
| REST API | `http://localhost:8080/f1-tickets/api/events` |
| WildFly Admin | `http://localhost:9990` |

---

## Seed Data & Purchase Simulation

The database is automatically initialised on first start via [`scripts/db/init-db.sh`](scripts/db/init-db.sh).

### What runs automatically on first boot

| Step | Script | Result |
|---|---|---|
| Schema | [`scripts/db/sql/01-schema.sql`](scripts/db/sql/01-schema.sql) | 4 tables + indexes created |
| Seed | [`scripts/db/sql/02-seed.sql`](scripts/db/sql/02-seed.sql) | 1 event, 800 GENERAL + 200 VIP tickets |
| Wave 1 | [`scripts/db/sql/03-purchases-auto.sql`](scripts/db/sql/03-purchases-auto.sql) | 300 tickets sold (250 GENERAL + 50 VIP), 60 purchases CONFIRMADA |

### Purchase simulation waves (manual)

Run these **inside the container** to progressively fill the event up to sold out:

| Script | Sells | Running total | Status |
|---|---|---|---|
| *(auto on boot)* | 300 | 300 / 1000 | 30% sold |
| [`simulate-purchases-wave2.sh`](scripts/simulation/simulate-purchases-wave2.sh) | 450 | 750 / 1000 | 75% sold |
| [`simulate-purchases-wave3.sh`](scripts/simulation/simulate-purchases-wave3.sh) | 250 | 1000 / 1000 | **SOLD OUT** |

```bash
podman exec -it f1-tickets bash /scripts/simulation/simulate-purchases-wave2.sh
podman exec -it f1-tickets bash /scripts/simulation/simulate-purchases-wave3.sh
```

All scripts are **idempotent** (`ON CONFLICT DO NOTHING`) and include a summary table at the end showing sold/available counts and total revenue.

### Resetting purchases

[`scripts/db/reset-purchases.sh`](scripts/db/reset-purchases.sh) wipes **all** purchases and brings the event back to zero — useful to restart a demo or simulation from scratch.

```bash
# Inside the container
podman exec -it f1-tickets bash /scripts/db/reset-purchases.sh

# From the host (with PostgreSQL accessible on localhost)
PGSQL_USER=appuser PGSQL_PASSWORD=apppassword PGSQL_DB=appdb \
  ./scripts/db/reset-purchases.sh
```

What it does in a single atomic transaction:
1. Deletes all rows in `purchase_tickets`
2. Deletes all rows in `purchases`
3. Sets `tickets.disponible = TRUE` for every ticket
4. Resets `events.entradas_vendidas = 0`

The script prints a before/after summary table so you can confirm the state of the database.

### Continuous random simulation (external)

[`scripts/simulation/simulate-purchases-random.sh`](scripts/simulation/simulate-purchases-random.sh) simulates purchases **from outside the container** by calling the REST API. It runs in an infinite loop until the event is sold out.

```bash
# Default target: http://localhost:8080/f1-tickets
./scripts/simulation/simulate-purchases-random.sh

# Custom target (e.g. OpenShift route)
./scripts/simulation/simulate-purchases-random.sh https://f1-tickets-f1-tickets.apps.<cluster>/f1-tickets
```

| Environment variable | Default | Description |
|---|---|---|
| `EVENT_ID` | `F1-2026-ESP` | Event ID to target |
| `MIN_WAIT` | `120` | Minimum seconds between purchases |
| `MAX_WAIT` | `600` | Maximum seconds between purchases |
| `MIN_TICKETS` | `1` | Minimum tickets per purchase |
| `MAX_TICKETS` | `4` | Maximum tickets per purchase |

The script auto-detects the OS (`jot` on macOS, `shuf` on Linux) and picks from a pool of 100 named buyers. The ticket type split is 70% GENERAL / 30% VIP.

### Loading additional tickets

[`scripts/simulation/load-tickets.sh`](scripts/simulation/load-tickets.sh) adds an extra batch of tickets beyond the original 1000:

| Type | Qty | Sections | Price |
|---|---|---|---|
| VIP | 48 | V3, V4 (4 rows × 6 seats) | €450 |
| GENERAL | 167 | G9–G16 (4 rows × 5 seats) + G17 row A (7 seats) | €150 |

```bash
podman exec -it f1-tickets bash /scripts/simulation/load-tickets.sh
```

---

## Modernisation Notes

Key modernisation paths from this monolith:

```
Current                         Target
──────────────────────────────────────────────────────
WildFly 18 (Java EE 7)    →    Open Liberty (Jakarta EE 10)
Java 8                    →    Java 17 / 21
Apache Struts 2           →    Jakarta Faces / Spring MVC / REST + SPA
Raw JDBC                  →    JPA / Hibernate
Co-located PostgreSQL     →    External managed database
Single container          →    Separate app + db containers / services
supervisord (PID 1)       →    Native container process management
```

---

## Repository Structure

```
f1-sales-tickets/
├── Containerfile                     Multi-stage container build (IBM AMA / OCI standard)
├── pom.xml                           Maven project descriptor
├── run-container.sh                  Helper script — auto-detects podman/docker, manages lifecycle
├── ama/
│   └── f1-sales-tickets.war_migrationPlan.zip   IBM AMA migration plan (WildFly → Liberty)
├── config/
│   ├── supervisord.conf              supervisord process definitions
│   └── wildfly-ds.cli                WildFly CLI datasource configuration
├── ocp/
│   └── deploy-all-in-one.yaml        Full OpenShift deployment manifest (11 resources)
├── scripts/
│   ├── entrypoint.sh                    Container entrypoint (PID 1 bootstrap)
│   ├── deploy.sh                        WildFly deployment helper (host-side)
│   ├── db/                              Database scripts
│   │   ├── init-db.sh                   PostgreSQL init — user, schema, seed (auto on first boot)
│   │   ├── reset-purchases.sh           Reset all purchases to 0 (wipe + free tickets)
│   │   └── sql/
│   │       ├── 01-schema.sql            Database schema (DDL)
│   │       ├── 02-seed.sql              Initial data (1 event, 1000 tickets)
│   │       └── 03-purchases-auto.sql    Wave 1 purchases — auto on first boot (300 sold)
│   └── simulation/                      Simulation scripts (REST API calls)
│       ├── load-tickets.sh              Load extra tickets at runtime (manual)
│       ├── simulate-purchases-wave2.sh  Simulate 450 more sales — 75% sold (manual, inside container)
│       ├── simulate-purchases-wave3.sh  Simulate final 250 sales — SOLD OUT (manual, inside container)
│       └── simulate-purchases-random.sh Continuous random simulation via REST API (external)
└── src/main/
    ├── java/com/ticketsales/        Application source code
    ├── resources/struts.xml         Struts 2 action mappings
    └── webapp/                      JSP views + web descriptors
```

---

## OpenShift Deployment

The [`ocp/deploy-all-in-one.yaml`](ocp/deploy-all-in-one.yaml) manifest deploys all required resources in a single file. It contains 11 resources applied in order. The `BuildConfig` uses `dockerfilePath: Containerfile` (OCI/IBM AMA standard naming).

| # | Resource | Description |
|---|---|---|
| 1 | `ProjectRequest` | Creates the `f1-tickets` namespace |
| 2 | `ClusterRoleBinding` anyuid | Allows the pod to run as root (required by PostgreSQL) |
| 3 | `ClusterRoleBinding` webhook | Allows GitHub to call the OCP webhook without authentication |
| 4 | `Secret` | PostgreSQL credentials |
| 5 | `PersistentVolumeClaim` | 2 Gi volume for PostgreSQL data |
| 6 | `ImageStream` | Target for the image built by the BuildConfig |
| 7 | `BuildConfig` | Builds the image from GitHub; triggered by webhook on push |
| 8 | `Deployment` | Runs the WildFly 18 + PostgreSQL 15 monolith |
| 9 | `Service` | Exposes port 8080 internally |
| 10 | `Route` | Exposes the app externally with TLS edge termination |

### Prerequisites

Before applying the manifest, replace the following placeholders:

| Placeholder | Description | Example |
|---|---|---|
| `<STORAGE_CLASSNAME>` | Storage class for the PVC | `crc-csi-hostpath-provisioner` (CRC) / `kubevirt-csi-infra-default` (OCP) |

### Apply (CLI)

```bash
# Requires kubeadmin session for cluster-scoped resources
oc apply -f ocp/deploy-all-in-one.yaml

# Trigger the first build manually
oc start-build f1-tickets -n f1-tickets --follow

# Watch the rollout
oc rollout status deployment/f1-tickets -n f1-tickets
```

### Access

| Environment | URL |
|---|---|
| CRC | `http://f1-tickets-f1-tickets.apps-crc.testing/f1-tickets` |
| OCP | `https://f1-tickets-f1-tickets.apps.<cluster>/f1-tickets` |

---

## CI/CD — Automatic Build on Git Push

The `BuildConfig` is configured with a **Generic Webhook** trigger. Every `git push` to `main` automatically starts a new OCP build and rolls out the updated image.

### Flow

```
git push main
    └─▶ GitHub Webhook (POST)
            └─▶ OCP BuildConfig (Docker strategy)
                    └─▶ ImageStream f1-tickets:latest
                            └─▶ Deployment rollout (automatic via image trigger)
```

### Webhook URL structure

```
https://<OCP_API_SERVER>:6443/apis/build.openshift.io/v1/namespaces/f1-tickets/buildconfigs/f1-tickets/webhooks/f1ocp2026/generic
```

Obtain the URL from the cluster:

```bash
oc describe bc/f1-tickets -n f1-tickets | grep -A2 "Webhook Generic"
```

### GitHub Webhook configuration

| Field | Value |
|---|---|
| Payload URL | URL obtained above |
| Content type | `application/json` |
| Secret | `f1ocp2026` |
| SSL verification | Enable (valid cert) / Disable (self-signed) |
| Events | `Just the push event` |

### Verify the pipeline

```bash
# Force a build manually
oc start-build f1-tickets -n f1-tickets --follow

# Watch builds
oc get builds -n f1-tickets -w

# Watch rollout
oc rollout status deployment/f1-tickets -n f1-tickets
```

---
