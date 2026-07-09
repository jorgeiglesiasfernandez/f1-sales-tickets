# F1-Tickets — Plan de Migración de Base de Datos

> **Objetivo**: Extraer la base de datos PostgreSQL del monolito legacy (`f1-tickets`)
> a un despliegue independiente, de forma que la aplicación legacy siga funcionando
> con su BD interna **y** la nueva BD esté disponible para la aplicación modernizada
> u otras aplicaciones futuras.

---

## Arquitectura antes y después

```
ANTES (monolito actual)
─────────────────────────────────────────────────────────────────
 Namespace: f1-tickets
 ┌────────────────────────────────────────────────────────────┐
 │  Pod: f1-tickets                                           │
 │  ┌─────────────────────┐  ┌──────────────────────────┐   │
 │  │  WildFly 18 (app)   │  │  PostgreSQL 15 (BD)      │   │
 │  │  :8080              │──│  appdb @ localhost:5432   │   │
 │  └─────────────────────┘  └──────────────────────────┘   │
 │                                       │                    │
 │                                PVC: f1-pgsql-data          │
 └────────────────────────────────────────────────────────────┘

DESPUÉS (estado objetivo)
─────────────────────────────────────────────────────────────────
 Namespace: f1-tickets  (legacy — no se modifica)
 ┌────────────────────────────────────────────────────────────┐
 │  Pod: f1-tickets                                           │
 │  ┌─────────────────────┐  ┌──────────────────────────┐   │
 │  │  WildFly 18 (app)   │  │  PostgreSQL 15 (BD)      │   │
 │  │  :8080              │──│  appdb @ localhost:5432   │   │
 │  └─────────────────────┘  └──────────────────────────┘   │
 │                                 (sin cambios)              │
 └────────────────────────────────────────────────────────────┘

 Namespace: f1-tickets-db  (nueva BD externa)
 ┌────────────────────────────────────────────────────────────┐
 │  Deployment: f1-external-db                                │
 │  ┌──────────────────────────────────────────────────┐     │
 │  │  PostgreSQL 15-alpine  (snapshot del legacy)     │     │
 │  │  appdb @ f1-external-db.f1-tickets-db.svc:5432   │     │
 │  └──────────────────────────────────────────────────┘     │
 │                      │                                     │
 │              PVC: f1-external-db-data (5Gi)                │
 └────────────────────────────────────────────────────────────┘

       ↑ Accesible desde cualquier namespace del cluster
       (f1-tickets-modern, otras apps, etc.)
```

---

## Estructura de ficheros

```
db-migration/
├── migrate-db.sh                        ← Script maestro orquestador
├── dumps/                               ← Directorio de dumps (se crea auto)
├── ocp/
│   └── deploy-external-db-ocp.yaml     ← Manifiesto OCP (namespace f1-tickets-db)
├── container/
│   └── compose.yml                     ← BD externa local, compatible Docker/Podman
└── scripts/
    ├── 01-dump-from-legacy-ocp.sh      ← Dump desde pod OCP legacy
    ├── 01-dump-from-legacy-container.sh← Dump desde contenedor local (Docker/Podman)
    ├── 03-restore-dump-ocp.sh          ← Restaurar dump en BD externa OCP
    └── 03-restore-dump-container.sh    ← Restaurar dump en BD externa local
```

> **Runtime agnóstico**: todos los scripts de contenedor detectan automáticamente
> `podman` o `docker` (podman tiene prioridad), siguiendo el mismo patrón que
> [`run-container.sh`](../run-container.sh).

---

## Flujo de migración paso a paso

### 🔵 OpenShift (OCP / CRC)

#### Prerequisitos
- `oc` CLI instalado con sesión activa (`oc login ...`)
- Permisos de kubeadmin para crear el namespace `f1-tickets-db`
- Conocer el `storageClassName` de tu cluster

#### Paso 1 — Configurar el StorageClass

Edita [`ocp/deploy-external-db-ocp.yaml`](ocp/deploy-external-db-ocp.yaml) y reemplaza:
```yaml
storageClassName: <STORAGE_CLASSNAME>
```
Por el valor correcto:
- **CRC**  → `crc-csi-hostpath-provisioner`
- **OCP**  → `kubevirt-csi-infra-default`

#### Paso 2 — Ejecutar la migración completa

```bash
cd db-migration
chmod +x migrate-db.sh scripts/*.sh
./migrate-db.sh --ocp
```

El script realizará automáticamente:
1. ✋ Para el pod legacy (`oc scale deployment f1-tickets --replicas=0`)
2. 💾 Extrae el dump con un Job temporal que monta el PVC
3. 📋 Copia el dump a `./dumps/f1-legacy-dump-YYYYMMDD-HHmmSS.sql`
4. 🗑️  Elimina el Job temporal
5. ▶️  Rearrancar el pod legacy (`--replicas=1`)
6. 🚀 Despliega la BD externa (`oc apply -f ocp/deploy-external-db-ocp.yaml`)
7. 📥 Restaura el dump en la nueva BD
8. ✅ Verifica tablas y recuentos

#### Paso 3 — Verificar la conexión desde otras apps

```bash
# Verificar que la BD está respondiendo
oc exec -n f1-tickets-db \
    $(oc get pod -n f1-tickets-db -l app=f1-external-db -o name | head -1) \
    -- psql -U appuser -d appdb -c "\dt"

# Ver el Service disponible para otras apps
oc get svc -n f1-tickets-db
```

---

### 🐳/🦭 Contenedor local (Docker o Podman)

Los scripts detectan automáticamente el runtime disponible (podman tiene prioridad).

#### Prerequisitos
- Podman o Docker instalado y en ejecución
- El contenedor legacy corriendo localmente (ver [`run-container.sh`](../run-container.sh))

#### Migración completa en un comando

```bash
cd db-migration
chmod +x migrate-db.sh scripts/*.sh

# Si el contenedor se llama "f1-tickets":
./migrate-db.sh --container f1-tickets

# O con auto-detect del contenedor:
./migrate-db.sh --container
```

El script realizará:
1. ✋ Para el contenedor legacy
2. 💾 Extrae el dump del volumen de datos (contenedor temporal)
3. 🚀 Levanta `f1-external-db` en puerto **5433** (compose up)
4. 📥 Restaura el dump
5. ▶️  Rearrancar el contenedor legacy
6. ✅ Verifica tablas y recuentos

#### Levantar solo la BD externa

```bash
# Con Docker:
docker compose -f db-migration/container/compose.yml up -d

# Con Podman:
podman compose -f db-migration/container/compose.yml up -d
```

---

## Modos de ejecución individuales

```bash
# Solo extraer el dump (sin desplegar ni restaurar):
./migrate-db.sh --ocp-dump-only
./migrate-db.sh --dump-only f1-tickets

# Solo restaurar un dump existente (BD ya desplegada/corriendo):
./migrate-db.sh --restore-ocp       ./dumps/f1-legacy-dump-20260101-120000.sql
./migrate-db.sh --restore-container ./dumps/f1-legacy-dump-20260101-120000.sql
```

---

## Conexión a la BD externa desde aplicaciones

### Desde una app en OCP (cualquier namespace):

```yaml
# En el Secret de tu nueva aplicación:
env:
  - name: DATABASE_URL
    value: "postgresql://appuser:apppassword@f1-external-db.f1-tickets-db.svc.cluster.local:5432/appdb"
```

### Desde un contenedor local o Docker Compose / Podman Compose:

```
Host:     localhost
Port:     5433
User:     appuser
Password: apppassword
DB:       appdb
URL:      postgresql://appuser:apppassword@localhost:5433/appdb
```

```bash
# Conectar con psql directamente:
podman exec -it f1-external-db psql -U appuser appdb
# o
docker exec -it f1-external-db psql -U appuser appdb
```

---

## Decisiones de diseño

| Decisión | Elección | Motivo |
|---|---|---|
| Ventana de mantenimiento | Parada controlada (stop → dump → start) | Consistencia total de datos sin riesgo de dirty reads |
| La legacy sigue intacta | Sí | No se modifica ni el Dockerfile ni la configuración del monolito |
| Credenciales | Idénticas a la legacy | La futura app modernizada es compatible sin cambios de config |
| Namespace | `f1-tickets-db` (independiente) | Aislamiento, posible reutilización por otras apps futuras |
| Puerto local | 5433 | Evita conflicto con el posible legacy en 5432 local |
| StorageClass OCP | Configurable (`<STORAGE_CLASSNAME>`) | Compatible con CRC y OCP productivo |
| NetworkPolicy | Definida | Solo `f1-tickets` y `f1-tickets-modern` pueden acceder |
| Runtime contenedor | Agnóstico (podman/docker) | Mismo patrón que `run-container.sh`; podman toma prioridad |
| Fichero compose | `compose.yml` | Detectado automáticamente por Docker Compose v2 y Podman Compose |

---

## Cómo conectar la futura app modernizada

Cuando desarrolles la aplicación modernizada, simplemente apunta su datasource a la BD externa:

```properties
# application.properties (Quarkus / Spring Boot)
quarkus.datasource.jdbc.url=jdbc:postgresql://f1-external-db.f1-tickets-db.svc.cluster.local:5432/appdb
quarkus.datasource.username=appuser
quarkus.datasource.password=apppassword
```

La aplicación legacy **sigue corriendo sin cambios** con su propia BD interna.

---

## Schema de la base de datos migrada

```
events           → Eventos F1 (Grand Prix)
tickets          → Entradas individuales por evento (GENERAL / VIP)
purchases        → Compras realizadas por compradores
purchase_tickets → Relación N:M entre compras y tickets
```

Consulta el schema completo en [`scripts/sql/01-schema.sql`](../scripts/sql/01-schema.sql).
