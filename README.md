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
| Container build | Podman / Docker multi-stage | `Containerfile` (OCI standard) |

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
| `DELETE` | `/purchases` | — | **Reset demo**: borra todas las compras y deja el evento a 0 vendidas |

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

**Respuesta `DELETE /purchases`:**
```json
{
  "success": true,
  "message": "Reset completado. Todas las compras han sido eliminadas y los tickets liberados.",
  "data": {
    "purchaseTicketsDeleted": 120,
    "purchasesDeleted": 60,
    "ticketsReleased": 300,
    "eventCounterReset": 1
  }
}
```

> El reset ejecuta en una única transacción atómica: borra `purchase_tickets`, borra `purchases`, libera todos los tickets (`disponible = TRUE`) y resetea `entradas_vendidas = 0`.

---

## Multi-stage Container Build

The [`Containerfile`](Containerfile) follows the **OCI standard** naming convention (`Containerfile` instead of `Dockerfile`) and uses a two-stage build so no local Maven or JDK installation is required:

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

### OCI Labels

| Label | Value |
|---|---|
| `org.opencontainers.image.title` | `f1-sales-tickets` |
| `org.opencontainers.image.vendor` | `IBM` |
| `org.opencontainers.image.source` | GitHub repository URL |
| `org.opencontainers.image.version` | `1.0.0` |
| `org.opencontainers.image.licenses` | `Apache-2.0` |

---

## Running Locally

[`deploy/local/run.sh`](deploy/local/run.sh) auto-detects **podman** or **docker** (podman takes priority) and the **native CPU architecture** (`arm64` / `amd64`), passing the correct `--platform` flag automatically. No manual configuration needed on Apple Silicon or x86_64.

### With the helper script (recommended)

```bash
./deploy/local/run.sh                # build + run (default)
./deploy/local/run.sh build          # build image for native arch only
./deploy/local/run.sh run            # start container (create if needed)
./deploy/local/run.sh stop           # stop the running container
./deploy/local/run.sh logs           # follow container logs
./deploy/local/run.sh destroy        # remove container and persistent volume
./deploy/local/run.sh hotdeploy      # mvn clean package + deploy WAR without rebuilding image
./deploy/local/run.sh multiarch-push # build amd64+arm64 manifest and push to registry
                                     # requires: export IMAGE_REGISTRY=quay.io/myorg
```

### Hot-deploy (without image rebuild)

Compiles the WAR with Maven and deploys it directly into the running WildFly instance — no container image rebuild needed. Ideal for fast iterative development.

```bash
# Requires: mvn in PATH + container running
./deploy/local/run.sh hotdeploy
```

Flow: `mvn clean package -DskipTests` → `podman/docker cp WAR` → `jboss-cli deploy --force`

### Manual commands

```bash
# Build for native architecture (podman or docker — both use Containerfile)
podman build -f Containerfile -t f1-sales-tickets .
docker build -f Containerfile -t f1-sales-tickets .

# Build targeting a specific platform explicitly
podman build --platform linux/arm64 -f Containerfile -t f1-sales-tickets .
podman build --platform linux/amd64 -f Containerfile -t f1-sales-tickets .

# Run with persistent volume
podman volume create f1-tickets-pgdata
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
# With the helper script
IMAGE_REGISTRY=quay.io/myorg ./deploy/local/run.sh multiarch-push

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
# Inside the container
podman exec -it f1-tickets bash /scripts/simulation/simulate-purchases-wave2.sh
podman exec -it f1-tickets bash /scripts/simulation/simulate-purchases-wave3.sh

# Against OCP
oc exec -it deployment/f1-tickets -n f1-tickets -- \
  bash /scripts/simulation/simulate-purchases-wave2.sh
```

All scripts are **idempotent** (`ON CONFLICT DO NOTHING`) and include a summary table at the end showing sold/available counts and total revenue.

### Resetting the demo (via REST API)

[`scripts/simulation/reset-demo.sh`](scripts/simulation/reset-demo.sh) calls `DELETE /api/purchases` to wipe all purchases and restore the event to zero — **no direct database access required**. Works against local or OCP targets. Compatible with macOS and Linux.

```bash
# Local
./scripts/simulation/reset-demo.sh

# OCP
./scripts/simulation/reset-demo.sh \
  https://f1-tickets-f1-tickets.apps.<cluster>/f1-tickets

# With environment variable
API_BASE_URL=https://f1-tickets-f1-tickets.apps.<cluster>/f1-tickets \
  ./scripts/simulation/reset-demo.sh
```

The script prints a before/after availability summary. After reset, the event is back at 0 sold / 1000 available and ready for a new demo run.

> **Direct DB reset (inside the container):** [`scripts/db/reset-purchases.sh`](scripts/db/reset-purchases.sh) performs the same operation via `psql` — useful when the app is not running or for debugging.

### Continuous random simulation (external)

[`scripts/simulation/simulate-purchases-random.sh`](scripts/simulation/simulate-purchases-random.sh) simulates purchases **from outside the container** by calling the REST API. It runs in an infinite loop until the event is sold out.

```bash
# Default target: http://localhost:8080/f1-tickets
./scripts/simulation/simulate-purchases-random.sh

# Custom target (e.g. OpenShift route)
./scripts/simulation/simulate-purchases-random.sh \
  https://f1-tickets-f1-tickets.apps.<cluster>/f1-tickets
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

[`scripts/simulation/load-tickets.sh`](scripts/simulation/load-tickets.sh) adds an extra batch of tickets beyond the original 1000 via the REST API:

| Type | Qty | Sections | Price |
|---|---|---|---|
| VIP | 48 | V3, V4 (4 rows × 6 seats) | €450 |
| GENERAL | 167 | G9–G16 (4 rows × 5 seats) + G17 row A (7 seats) | €150 |

```bash
podman exec -it f1-tickets bash /scripts/simulation/load-tickets.sh
```

### Typical demo flow

```
1. Start              ./deploy/local/run.sh
                      (auto-boot: schema + seed + wave 1 → 300 sold)

2. Show UI            http://localhost:8080/f1-tickets

3. Simulate sales     ./scripts/simulation/simulate-purchases-wave2.sh   → 750/1000
                      ./scripts/simulation/simulate-purchases-wave3.sh   → SOLD OUT

4. Reset for next     ./scripts/simulation/reset-demo.sh                 → 0/1000
   demo run

5. Or continuous      ./scripts/simulation/simulate-purchases-random.sh
   random sales
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
├── Containerfile                          Multi-stage build (OCI standard)
├── pom.xml                                Maven project descriptor
├── README.md
│
├── deploy/                                Build & deploy — entry point for all environments
│   ├── local/
│   │   └── run.sh                         Local: build/run/stop/destroy/logs/hotdeploy/multiarch-push
│   └── ocp/
│       ├── deploy.sh                      OCP CLI: apply/build/hotdeploy/status/logs/rollout/destroy/webhook
│       ├── all-in-one.yaml                All resources (web console / kubectl / GitOps)
│       └── manifests/                     Individual manifests (apply selectively)
│           ├── 00-project.yaml            ProjectRequest + ClusterRoleBindings (kubeadmin)
│           ├── 01-secrets.yaml            Secret — PostgreSQL credentials
│           ├── 02-storage.yaml            PersistentVolumeClaim (replace <STORAGE_CLASSNAME>)
│           ├── 03-build.yaml              ImageStream + BuildConfig (GitHub → Containerfile)
│           └── 04-app.yaml               Deployment + Service + Route
│
├── config/                                Runtime config (copied into the container image)
│   ├── supervisord.conf                   supervisord process definitions
│   └── wildfly-ds.cli                     WildFly CLI datasource configuration
│
├── scripts/                               Scripts used inside the container
│   ├── entrypoint.sh                      PID 1: init PostgreSQL + WildFly DS + supervisord
│   ├── db/                                Database management (direct psql access)
│   │   ├── init-db.sh                     PostgreSQL init — user, schema, seed (auto on first boot)
│   │   ├── reset-purchases.sh             Direct DB reset via psql (alternative to REST endpoint)
│   │   └── sql/
│   │       ├── 01-schema.sql              Database schema (DDL)
│   │       ├── 02-seed.sql                Initial data (1 event, 1000 tickets)
│   │       └── 03-purchases-auto.sql      Wave 1 purchases — auto on first boot (300 sold)
│   └── simulation/                        Simulation & demo scripts (REST API calls)
│       ├── reset-demo.sh                  Reset all purchases via DELETE /api/purchases (macOS + Linux)
│       ├── load-tickets.sh                Load extra tickets via POST /api/tickets
│       ├── simulate-purchases-wave2.sh    Simulate 450 more sales → 75% sold
│       ├── simulate-purchases-wave3.sh    Simulate final 250 sales → SOLD OUT
│       └── simulate-purchases-random.sh   Continuous random simulation via REST API (external)
│
└── src/main/
    ├── java/com/ticketsales/              Application source code
    ├── resources/struts.xml               Struts 2 action mappings
    └── webapp/                            JSP views + web descriptors
```

---

## OpenShift Deployment

Two deployment options are available under [`deploy/ocp/`](deploy/ocp/):

| File | Use case |
|---|---|
| [`deploy/ocp/deploy.sh`](deploy/ocp/deploy.sh) | CLI script — full lifecycle management with `oc` |
| [`deploy/ocp/all-in-one.yaml`](deploy/ocp/all-in-one.yaml) | Web console / `kubectl apply` / GitOps — no `oc` client needed |
| [`deploy/ocp/manifests/`](deploy/ocp/manifests/) | Individual YAMLs — apply or update resources selectively |

### Resources

| # | Resource | Manifest | Description |
|---|---|---|---|
| 1 | `ProjectRequest` | `00-project.yaml` | Creates the `f1-tickets` namespace |
| 2 | `ClusterRoleBinding` anyuid | `00-project.yaml` | Allows the pod to run as root (required by PostgreSQL) |
| 3 | `ClusterRoleBinding` webhook | `00-project.yaml` | Allows GitHub to call the OCP webhook without authentication |
| 4 | `Secret` | `01-secrets.yaml` | PostgreSQL credentials |
| 5 | `PersistentVolumeClaim` | `02-storage.yaml` | 2 Gi volume for PostgreSQL data |
| 6 | `ImageStream` | `03-build.yaml` | Target for the image built by the BuildConfig |
| 7 | `BuildConfig` | `03-build.yaml` | Builds from GitHub using `Containerfile`; triggered by webhook on push |
| 8 | `Deployment` | `04-app.yaml` | Runs the WildFly 18 + PostgreSQL 15 monolith |
| 9 | `Service` | `04-app.yaml` | Exposes port 8080 internally |
| 10 | `Route` | `04-app.yaml` | Exposes the app externally with TLS edge termination |

### Prerequisites

Before applying, replace the storage class placeholder in [`deploy/ocp/manifests/02-storage.yaml`](deploy/ocp/manifests/02-storage.yaml):

| Placeholder | Description | Example |
|---|---|---|
| `<STORAGE_CLASSNAME>` | Storage class for the PVC | `crc-csi-hostpath-provisioner` (CRC) / `kubevirt-csi-infra-default` (OCP) |

### Option A — CLI script (recommended)

```bash
oc login https://<cluster>:6443 -u kubeadmin -p <pass>

# Replace storage class
sed -i 's/<STORAGE_CLASSNAME>/crc-csi-hostpath-provisioner/' \
  deploy/ocp/manifests/02-storage.yaml

# Apply all resources + launch first build + wait for rollout
./deploy/ocp/deploy.sh apply

# Additional commands
./deploy/ocp/deploy.sh status     # pods, builds, route URL
./deploy/ocp/deploy.sh logs       # follow pod logs
./deploy/ocp/deploy.sh build      # trigger a new image build
./deploy/ocp/deploy.sh hotdeploy  # mvn package + copy WAR to pod (no image rebuild)
./deploy/ocp/deploy.sh rollout    # force redeploy without new build
./deploy/ocp/deploy.sh webhook    # show GitHub webhook URL
./deploy/ocp/deploy.sh destroy    # delete namespace (prompts for confirmation)
```

### Option B — Web console / kubectl (no oc client required)

```bash
# With kubectl
kubectl apply -f deploy/ocp/all-in-one.yaml

# Or from the OCP web console:
# 1. Login as kubeadmin
# 2. "+" (Import YAML) → paste deploy/ocp/all-in-one.yaml → Create
# 3. Builds → BuildConfigs → f1-tickets → Start Build
# 4. Networking → Routes → f1-tickets → open URL
```

### Hot-deploy in OCP (without image rebuild)

Compiles the WAR locally and copies it directly into the running pod's WildFly instance:

```bash
# Requires: mvn in PATH + oc session active + pod Running
./deploy/ocp/deploy.sh hotdeploy
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
            └─▶ OCP BuildConfig (Containerfile strategy)
                    └─▶ ImageStream f1-tickets:latest
                            └─▶ Deployment rollout (automatic via image trigger)
```

### Webhook URL structure

```
https://<OCP_API_SERVER>:6443/apis/build.openshift.io/v1/namespaces/f1-tickets/buildconfigs/f1-tickets/webhooks/f1ocp2026/generic
```

Obtain the URL from the cluster:

```bash
./deploy/ocp/deploy.sh webhook
# or manually:
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
./deploy/ocp/deploy.sh status   # pods + builds + route
./deploy/ocp/deploy.sh build    # trigger build manually
./deploy/ocp/deploy.sh logs     # follow pod logs
```

---
