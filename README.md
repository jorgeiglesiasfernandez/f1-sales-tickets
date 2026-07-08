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
| Container build | Docker multi-stage | — |

---

## REST API

Base path: `/f1-tickets/api`

| Method | Path | Description |
|---|---|---|
| `GET` | `/events` | List all events |
| `GET` | `/events/{id}` | Get event by ID |
| `GET` | `/tickets` | List all tickets |
| `GET` | `/tickets/availability/{eventId}` | Ticket availability for an event |
| `GET` | `/purchases` | List all purchases |
| `POST` | `/purchases` | Create a new purchase |

---

## Multi-stage Docker Build

The [`Dockerfile`](Dockerfile) uses a two-stage build so no local Maven or JDK installation is required:

```
Stage 1 — builder (maven:3.9-eclipse-temurin-8)
  └── mvn clean package → f1-sales-tickets.war

Stage 2 — runtime (almalinux:8)
  ├── Install PostgreSQL 15 (PGDG repo, auto-detects amd64/arm64)
  ├── Install WildFly 18
  ├── Install supervisord
  └── Copy WAR from stage 1
```

The image is **multi-architecture** (`amd64` + `arm64`) — the `TARGETARCH` build argument selects the correct PostgreSQL repository at build time. No separate Dockerfile is needed for Apple Silicon or ARM-based nodes.

---

## Running Locally

### With the helper script (recommended)

[`run-container.sh`](run-container.sh) auto-detects **podman** or **docker** (podman takes priority) and manages the full lifecycle:

```bash
./run-container.sh           # build + run (default)
./run-container.sh build     # build image only
./run-container.sh run       # start container (create if needed)
./run-container.sh stop      # stop the running container
./run-container.sh logs      # follow container logs
./run-container.sh destroy   # remove container and persistent volume
```

### Manual commands

```bash
# Build
podman build -t f1-sales-tickets .   # or: docker build -t f1-sales-tickets .

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

### Access

| Endpoint | URL |
|---|---|
| Web UI | `http://localhost:8080/f1-tickets` |
| REST API | `http://localhost:8080/f1-tickets/api/events` |
| WildFly Admin | `http://localhost:9990` |

---

## Seed Data & Purchase Simulation

The database is automatically initialised on first start via [`scripts/init-db.sh`](scripts/init-db.sh).

### What runs automatically on first boot

| Step | Script | Result |
|---|---|---|
| Schema | [`scripts/sql/01-schema.sql`](scripts/sql/01-schema.sql) | 4 tables + indexes created |
| Seed | [`scripts/sql/02-seed.sql`](scripts/sql/02-seed.sql) | 1 event, 800 GENERAL + 200 VIP tickets |
| Wave 1 | [`scripts/sql/03-purchases-auto.sql`](scripts/sql/03-purchases-auto.sql) | 300 tickets sold (250 GENERAL + 50 VIP), 60 purchases CONFIRMADA |

### Purchase simulation waves (manual)

Run these **inside the container** to progressively fill the event up to sold out:

| Script | Sells | Running total | Status |
|---|---|---|---|
| *(auto on boot)* | 300 | 300 / 1000 | 30% sold |
| [`simulate-purchases-wave2.sh`](scripts/simulate-purchases-wave2.sh) | 450 | 750 / 1000 | 75% sold |
| [`simulate-purchases-wave3.sh`](scripts/simulate-purchases-wave3.sh) | 250 | 1000 / 1000 | **SOLD OUT** |

```bash
podman exec -it f1-tickets bash /scripts/simulate-purchases-wave2.sh
podman exec -it f1-tickets bash /scripts/simulate-purchases-wave3.sh
```

All scripts are **idempotent** (`ON CONFLICT DO NOTHING`) and include a summary table at the end showing sold/available counts and total revenue.

### Loading additional tickets

[`scripts/load-tickets.sh`](scripts/load-tickets.sh) adds an extra batch of tickets beyond the original 1000:

| Type | Qty | Sections | Price |
|---|---|---|---|
| VIP | 48 | V3, V4 (4 rows × 6 seats) | €450 |
| GENERAL | 167 | G9–G16 (4 rows × 5 seats) + G17 row A (7 seats) | €150 |

```bash
podman exec -it f1-tickets bash /scripts/load-tickets.sh
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
├── Dockerfile                        Multi-stage container build
├── pom.xml                           Maven project descriptor
├── run-container.sh                  Helper script — auto-detects podman/docker, manages lifecycle
├── config/
│   ├── supervisord.conf              supervisord process definitions
│   └── wildfly-ds.cli                WildFly CLI datasource configuration
├── ocp/
│   └── deploy-all-in-one.yaml        Full OpenShift deployment manifest (11 resources)
├── scripts/
│   ├── entrypoint.sh                    Container entrypoint
│   ├── init-db.sh                       PostgreSQL initialisation script
│   ├── load-tickets.sh                  Load extra tickets at runtime (manual)
│   ├── simulate-purchases-wave2.sh      Simulate 450 more sales — 75% sold (manual)
│   ├── simulate-purchases-wave3.sh      Simulate final 250 sales — SOLD OUT (manual)
│   ├── deploy.sh                        WildFly deployment helper
│   └── sql/
│       ├── 01-schema.sql                Database schema
│       ├── 02-seed.sql                  Initial data (1 event, 1000 tickets)
│       └── 03-purchases-auto.sql        Wave 1 purchases — auto on first boot (300 sold)
└── src/main/
    ├── java/com/ticketsales/        Application source code
    ├── resources/struts.xml         Struts 2 action mappings
    └── webapp/                      JSP views + web descriptors
```

---

## OpenShift Deployment

The [`ocp/deploy-all-in-one.yaml`](ocp/deploy-all-in-one.yaml) manifest deploys all required resources in a single file. It contains 11 resources applied in order:

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

### Apply

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

## VM Simulation

The `Deployment` is configured with **Guaranteed QoS** resource requests and limits to simulate the footprint of a large virtual machine. 

| Resource | Request = Limit | VM equivalent |
|---|---|---|
| CPU | `8000m` | 8 vCPU |
| Memory | `16Gi` | 16 GB RAM |
| Ephemeral storage | `40Gi` | 40 GB local disk |
| Persistent storage (PVC) | `2Gi` | PostgreSQL data disk |

> **QoS class: Guaranteed** — `requests == limits` ensures charges the full VM profile cost without proration. The PVC is billed separately as persistent storage cost.
