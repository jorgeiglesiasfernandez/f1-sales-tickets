#!/usr/bin/env bash
# ==============================================================================
# 01-dump-from-legacy-ocp.sh
#
# PASO 1 (OCP) — Parada controlada, extracción del dump y rearranque del pod
#                legacy en OpenShift.
#
# Qué hace:
#   1. Escala el Deployment legacy a 0 réplicas  (ventana de mantenimiento)
#   2. Espera a que el pod termine limpiamente
#   3. Crea un Job temporal que monta el PVC f1-pgsql-data y ejecuta pg_dump
#   4. Copia el fichero .sql resultante a la máquina local
#   5. Elimina el Job temporal
#   6. Vuelve a escalar el Deployment legacy a 1 réplica
#
# Prerrequisitos:
#   - oc CLI instalado y con sesión activa (oc whoami)
#   - Permisos para escalar Deployments y crear Jobs en el namespace f1-tickets
#   - El PVC f1-pgsql-data debe estar en modo ReadWriteOnce (solo un pod lo monta)
#
# Uso:
#   ./01-dump-from-legacy-ocp.sh [output_dir]
#   Ejemplo: ./01-dump-from-legacy-ocp.sh ./dumps
# ==============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------
NAMESPACE="f1-tickets"
DEPLOYMENT="f1-tickets"
PVC_NAME="f1-pgsql-data"
PG_VERSION="15"
PGSQL_USER="appuser"
PGSQL_DB="appdb"
PGSQL_DATA="/var/lib/pgsql/15/data"
JOB_NAME="f1-db-dump-job"
DUMP_FILE="f1-legacy-dump-$(date +%Y%m%d-%H%M%S).sql"
OUTPUT_DIR="${1:-./dumps}"

mkdir -p "${OUTPUT_DIR}"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   F1-Tickets — Extracción de BD desde pod legacy (OCP)  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Namespace  : ${NAMESPACE}"
echo "  Deployment : ${DEPLOYMENT}"
echo "  PVC        : ${PVC_NAME}"
echo "  DB         : ${PGSQL_DB}"
echo "  Dump file  : ${OUTPUT_DIR}/${DUMP_FILE}"
echo ""

# Verificar sesión oc activa
if ! oc whoami &>/dev/null; then
    echo "✗ No hay sesión oc activa. Ejecuta: oc login <cluster>"
    exit 1
fi

# ---------------------------------------------------------------------------
# PASO 1 — Escalar legacy a 0 (parada controlada)
# ---------------------------------------------------------------------------
echo "→ [1/6] Escalando Deployment '${DEPLOYMENT}' a 0 réplicas (mantenimiento)..."
oc scale deployment "${DEPLOYMENT}" --replicas=0 -n "${NAMESPACE}"

echo "  Esperando a que el pod termine..."
oc rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=120s || true

# Esperar hasta que no haya pods running
until [[ $(oc get pods -n "${NAMESPACE}" -l app="${DEPLOYMENT}" \
           --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l) -eq 0 ]]; do
    echo "  … pod aún activo, esperando..."
    sleep 5
done
echo "✓ Pod legacy detenido."

# ---------------------------------------------------------------------------
# PASO 2 — Limpiar Job previo si existiera (idempotencia)
# ---------------------------------------------------------------------------
echo "→ [2/6] Limpiando Job previo si existe..."
oc delete job "${JOB_NAME}" -n "${NAMESPACE}" --ignore-not-found=true
sleep 2

# ---------------------------------------------------------------------------
# PASO 3 — Crear Job temporal para ejecutar pg_dump
#           Monta el mismo PVC en modo lectura para no modificar datos
# ---------------------------------------------------------------------------
echo "→ [3/6] Creando Job de dump (pg_dump)..."

cat <<EOF | oc apply -n "${NAMESPACE}" -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: f1-tickets-db-dump
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pg-dump
        image: docker.io/library/postgres:15-alpine
        command:
        - /bin/sh
        - -c
        - |
          set -e
          # Arrancar PostgreSQL desde los datos del PVC
          chown -R postgres:postgres ${PGSQL_DATA}
          su -s /bin/sh postgres -c "pg_ctl -D ${PGSQL_DATA} start -w -t 60" >&2
          # Hacer el dump completo — stdout=SQL puro, stderr=progreso pg_dump
          su -s /bin/sh postgres -c \
            "pg_dump -U ${PGSQL_USER} -d ${PGSQL_DB} --no-password -F p -v 2>/dev/stderr"
          # Detener PostgreSQL
          su -s /bin/sh postgres -c "pg_ctl -D ${PGSQL_DATA} stop" >&2
        env:
        - name: PGPASSWORD
          value: "apppassword"
        - name: PGSQL_DATA
          value: "${PGSQL_DATA}"
        volumeMounts:
        - name: pgsql-data
          mountPath: ${PGSQL_DATA}
          subPath: data
          readOnly: false
      volumes:
      - name: pgsql-data
        persistentVolumeClaim:
          claimName: ${PVC_NAME}
EOF

# ---------------------------------------------------------------------------
# PASO 4 — Esperar a que el Job termine y extraer el dump desde los logs
# ---------------------------------------------------------------------------
echo "→ [4/6] Esperando a que el Job de dump termine..."
oc wait job/"${JOB_NAME}" -n "${NAMESPACE}" \
   --for=condition=complete --timeout=300s

# Obtener el nombre del pod del Job
DUMP_POD=$(oc get pods -n "${NAMESPACE}" -l job-name="${JOB_NAME}" \
           --no-headers -o custom-columns=":metadata.name")

echo "  Pod del dump: ${DUMP_POD}"

# El dump viajó por stdout; los mensajes de progreso por stderr.
# oc logs captura stdout del contenedor → es el SQL puro.
echo "→ Extrayendo dump desde logs del pod (stdout)..."
oc logs "${DUMP_POD}" -n "${NAMESPACE}" > "${OUTPUT_DIR}/${DUMP_FILE}"

if [[ -s "${OUTPUT_DIR}/${DUMP_FILE}" ]]; then
    DUMP_SIZE=$(du -sh "${OUTPUT_DIR}/${DUMP_FILE}" | cut -f1)
    echo "✓ Dump guardado: ${OUTPUT_DIR}/${DUMP_FILE} (${DUMP_SIZE})"
else
    echo "✗ Error: el dump está vacío o no se pudo extraer."
    rm -f "${OUTPUT_DIR}/${DUMP_FILE}"
    exit 1
fi

# ---------------------------------------------------------------------------
# PASO 5 — Eliminar Job temporal
# ---------------------------------------------------------------------------
echo "→ [5/6] Eliminando Job temporal..."
oc delete job "${JOB_NAME}" -n "${NAMESPACE}" --ignore-not-found=true
echo "✓ Job eliminado."

# ---------------------------------------------------------------------------
# PASO 6 — Rearrancar la aplicación legacy
# ---------------------------------------------------------------------------
echo "→ [6/6] Reescalando Deployment legacy a 1 réplica (fin del mantenimiento)..."
oc scale deployment "${DEPLOYMENT}" --replicas=1 -n "${NAMESPACE}"
oc rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=180s
echo "✓ Aplicación legacy arrancada de nuevo."

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✓  Extracción completada con éxito                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Fichero de dump: ${OUTPUT_DIR}/${DUMP_FILE}"
echo ""
echo "  Siguiente paso:"
echo "    OCP       → ./migrate-db.sh --restore-ocp ${OUTPUT_DIR}/<dump_file>"
echo "    Container → ./migrate-db.sh --restore-container ${OUTPUT_DIR}/<dump_file>"
echo ""
