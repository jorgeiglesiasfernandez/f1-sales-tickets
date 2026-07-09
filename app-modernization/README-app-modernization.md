# F1-Tickets — Modernización a IBM WebSphere Liberty 25

> **Objetivo**: Desplegar la aplicación F1-Tickets modernizada sobre
> **IBM WebSphere Liberty 25** conectada a la BD PostgreSQL externa
> (`f1-external-db` en namespace `f1-tickets-db`).

---

## Arquitectura antes y después

```
ANTES (monolito legacy)
─────────────────────────────────────────────────────────────────
 Namespace: f1-tickets
 ┌────────────────────────────────────────────────────────────┐
 │  Pod: f1-tickets                                           │
 │  ┌─────────────────────┐  ┌──────────────────────────┐   │
 │  │  WildFly 18 (app)   │  │  PostgreSQL 15 (BD)      │   │
 │  │  :8080              │──│  appdb @ localhost:5432   │   │
 │  └─────────────────────┘  └──────────────────────────┘   │
 └────────────────────────────────────────────────────────────┘

DESPUÉS (app modernizada)
─────────────────────────────────────────────────────────────────
 Namespace: f1-tickets-modern
 ┌────────────────────────────────────────────────────────────┐
 │  Pod: f1-liberty                                           │
 │  ┌─────────────────────────────────────────────────────┐  │
 │  │  IBM WebSphere Liberty 25  (app)                    │  │
 │  │  :9080 (HTTP)  :9443 (HTTPS)                        │  │
 │  └────────────────────────────┬────────────────────────┘  │
 └───────────────────────────────│────────────────────────────┘
                                 │ JDBC
 Namespace: f1-tickets-db        ▼
 ┌────────────────────────────────────────────────────────────┐
 │  Deployment: f1-external-db                                │
 │  PostgreSQL 15 @ f1-external-db.f1-tickets-db.svc:5432    │
 └────────────────────────────────────────────────────────────┘
```

---

## Estructura de ficheros

```
app-modernization/
├── deploy-liberty.sh                    ← Script maestro orquestador
├── ocp/
│   └── deploy-liberty-ocp.yaml         ← Manifiesto OCP (namespace f1-tickets-modern)
├── container/
│   └── compose.yml                     ← App Liberty + BD externa, compatible Docker/Podman
└── scripts/
    ├── 01-build-image-container.sh     ← Compila Maven y construye imagen Liberty local
    ├── 01-build-image-ocp.sh           ← Lanza BuildConfig en OCP
    ├── 02-deploy-container.sh          ← Despliega Liberty en contenedor local
    └── 02-deploy-ocp.sh                ← Despliega Liberty en OpenShift
```

> **Runtime agnóstico**: todos los scripts de contenedor detectan automáticamente
> `podman` o `docker` (podman tiene prioridad), siguiendo el mismo patrón que
> [`run-container.sh`](../run-container.sh) y los scripts de [`db-migration/`](../db-migration/).

---

## Prerrequisitos

### Comunes
- BD externa disponible con los datos migrados (ver [`db-migration/`](../db-migration/))
- Proyecto compilado (`target/f1-sales-tickets-1.0.0.war`)

### Para contenedor local
- Podman o Docker instalado y en ejecución
- Maven 3.x y JDK 8 en el PATH

### Para OpenShift (OCP / CRC)
- `oc` CLI instalado y sesión activa (`oc login ...`)
- Permisos para crear proyectos/namespaces
- BD externa desplegada en `f1-tickets-db` (ver `db-migration/ocp/`)

---

## Flujo de despliegue

### 🔵 OpenShift (OCP / CRC)

#### Paso 1 — Configurar el manifiesto

Edita [`ocp/deploy-liberty-ocp.yaml`](ocp/deploy-liberty-ocp.yaml) y reemplaza:

```yaml
uri: https://github.com/<TU_USUARIO>/f1-sales-tickets.git
```

#### Paso 2 — Despliegue completo en un comando

```bash
cd app-modernization
chmod +x deploy-liberty.sh scripts/*.sh
./deploy-liberty.sh --ocp
```

El script realizará automáticamente:
1. 📋 Aplica el manifiesto OCP (namespace, BuildConfig, Deployment, Service, Route)
2. 🔨 Lanza el build en OCP (descarga fuentes desde Git, compila Maven, construye imagen)
3. 🚀 Despliega el pod Liberty conectado a la BD externa
4. ✅ Verifica el rollout y muestra la URL de acceso

#### Verificar la BD externa antes del despliegue

```bash
# Asegúrate de que la BD externa está desplegada:
oc get deployment f1-external-db -n f1-tickets-db
oc get pods -n f1-tickets-db
```

#### Verificar el despliegue

```bash
oc get pods -n f1-tickets-modern
oc logs -f deployment/f1-liberty -n f1-tickets-modern
oc get route f1-liberty -n f1-tickets-modern
```

---

### 🐳/🦭 Contenedor local (Docker o Podman)

Los scripts detectan automáticamente el runtime disponible (podman tiene prioridad).

#### Prerrequisito — BD externa corriendo localmente

```bash
# Con Docker:
docker compose -f db-migration/container/compose.yml up -d

# Con Podman:
podman compose -f db-migration/container/compose.yml up -d
```

#### Despliegue completo en un comando

```bash
cd app-modernization
chmod +x deploy-liberty.sh scripts/*.sh
./deploy-liberty.sh --container
```

El script realizará:
1. 🔨 Compila el proyecto Maven (`mvn clean package`)
2. 📦 Construye la imagen Liberty usando el `Containerfile`
3. 🚀 Arranca el contenedor Liberty conectado a `f1-external-db`
4. ✅ Verifica que la app responde en `http://localhost:9080/f1-tickets`

#### Usando compose (recomendado para desarrollo)

```bash
cd app-modernization/container

# Con Docker:
docker compose up -d

# Con Podman:
podman compose up -d
```

---

## Modos de ejecución individuales

```bash
# Solo construir la imagen local (sin desplegar):
./deploy-liberty.sh --build-only
./deploy-liberty.sh --build-only f1-liberty:1.0.0

# Solo lanzar el build en OCP (sin desplegar):
./deploy-liberty.sh --ocp-build-only

# Solo desplegar (imagen ya construida):
./deploy-liberty.sh --deploy-ocp
./deploy-liberty.sh --deploy-container
./deploy-liberty.sh --deploy-container f1-liberty:1.0.0
```

---

## Conexión de la app modernizada a la BD externa

La aplicación Liberty usa el datasource JNDI `jdbc/AppDS` configurado en
[`src/main/liberty/config/server.xml`](../src/main/liberty/config/server.xml):

```xml
<dataSource id="AppDS" jndiName="jdbc/AppDS">
    <jdbcDriver libraryRef="PostgreSQLLib"/>
    <properties.postgresql
        serverName="f1-external-db.f1-tickets-db.svc.cluster.local"
        portNumber="5432"
        databaseName="appdb"
        user="appuser"
        password="apppassword"/>
</dataSource>
```

| Entorno | Host | Puerto |
|---|---|---|
| OCP / CRC | `f1-external-db.f1-tickets-db.svc.cluster.local` | `5432` |
| Local (contenedor) | `f1-external-db` (red interna compose) | `5432` |
| Local (host) | `localhost` | `5433` |

---

## URLs de la app modernizada

| Entorno | URL |
|---|---|
| OCP / CRC | `https://f1-liberty-f1-tickets-modern.apps-crc.testing/f1-tickets` |
| Local | `http://localhost:9080/f1-tickets` |
| REST API | `<base_url>/api/events` |

---

## Relación con la app legacy

La aplicación legacy (`f1-tickets` en namespace `f1-tickets`) **sigue corriendo
sin cambios** con su propia BD interna embebida. Ambas conviven en paralelo
durante el período de transición.

```
Namespace f1-tickets       →  WildFly 18  + PostgreSQL 15 (BD interna)
Namespace f1-tickets-modern →  Liberty 25  + PostgreSQL 15 (BD externa compartida)
Namespace f1-tickets-db    →  PostgreSQL 15 standalone (BD externa)
```
