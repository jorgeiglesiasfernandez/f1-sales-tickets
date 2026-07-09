#!/usr/bin/env bash
# ==============================================================================
# 01-build-image-container.sh
#
# PASO 1 (container) — Compila el proyecto Maven y construye la imagen
#                      Liberty con Podman o Docker.
#
# Automáticamente detecta podman o docker (podman tiene prioridad).
#
# Qué hace:
#   1. Verifica que mvn y el container runtime estén disponibles
#   2. Compila el proyecto Maven (mvn clean package)
#   3. Construye la imagen Liberty usando el Containerfile
#   4. Verifica que la imagen se ha creado correctamente
#
# Prerrequisitos:
#   - Maven 3.x y JDK 8 en el PATH
#   - Podman o Docker instalado y en ejecución
#   - Ejecutar desde el directorio raíz del proyecto
#
# Uso:
#   ./01-build-image-container.sh [image_tag]
#   Ejemplo: ./01-build-image-container.sh f1-liberty:latest
# ==============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Detectar runtime: podman tiene prioridad sobre docker
# ---------------------------------------------------------------------------
if command -v podman &>/dev/null; then
    CTR="podman"
elif command -v docker &>/dev/null; then
    CTR="docker"
else
    echo "✗ Neither podman nor docker found. Please install one of them." >&2
    exit 1
fi

echo "→ Using container runtime: ${CTR}"

# ---------------------------------------------------------------------------
# Argumentos y configuración
# ---------------------------------------------------------------------------
IMAGE_TAG="${1:-f1-liberty:latest}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  F1-Tickets — Build imagen Liberty (container local)         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Runtime      : ${CTR}"
echo "  Imagen       : ${IMAGE_TAG}"
echo "  Proyecto     : ${PROJECT_DIR}"
echo ""

# ---------------------------------------------------------------------------
# PASO 1 — Verificar prerrequisitos
# ---------------------------------------------------------------------------
echo "→ [1/4] Verificando prerrequisitos..."

if ! command -v mvn &>/dev/null; then
    echo "✗ Maven (mvn) no encontrado. Instala Maven 3.x y asegúrate de que está en el PATH."
    exit 1
fi

if ! command -v java &>/dev/null; then
    echo "✗ Java no encontrado. Instala JDK 8 o superior."
    exit 1
fi

MVN_VERSION=$(mvn --version | head -1)
JAVA_VERSION=$(java -version 2>&1 | head -1)
echo "✓ Maven : ${MVN_VERSION}"
echo "✓ Java  : ${JAVA_VERSION}"
echo "✓ Runtime: ${CTR}"

# ---------------------------------------------------------------------------
# PASO 2 — Compilar el proyecto Maven
# ---------------------------------------------------------------------------
echo "→ [2/4] Compilando proyecto Maven (mvn clean package)..."
echo "  (Esto puede tardar unos minutos la primera vez)"

cd "${PROJECT_DIR}"
mvn clean package -DskipTests -q

WAR_FILE=$(ls target/*.war 2>/dev/null | head -1 || true)
if [[ -z "${WAR_FILE}" ]]; then
    echo "✗ No se generó el fichero WAR en target/. Revisa la compilación Maven."
    exit 1
fi
WAR_SIZE=$(du -sh "${WAR_FILE}" | cut -f1)
echo "✓ WAR generado: ${WAR_FILE} (${WAR_SIZE})"

# ---------------------------------------------------------------------------
# PASO 3 — Construir la imagen Liberty con Containerfile
# ---------------------------------------------------------------------------
echo "→ [3/4] Construyendo imagen Liberty '${IMAGE_TAG}'..."
echo "  Usando Containerfile en: ${PROJECT_DIR}/Containerfile"

${CTR} build \
    --no-cache \
    -t "${IMAGE_TAG}" \
    -f "${PROJECT_DIR}/Containerfile" \
    "${PROJECT_DIR}"

echo "✓ Imagen construida: ${IMAGE_TAG}"

# ---------------------------------------------------------------------------
# PASO 4 — Verificar la imagen
# ---------------------------------------------------------------------------
echo "→ [4/4] Verificando imagen..."

IMAGE_ID=$(${CTR} images --format "{{.ID}}" "${IMAGE_TAG}" 2>/dev/null | head -1 || true)
if [[ -z "${IMAGE_ID}" ]]; then
    echo "✗ La imagen '${IMAGE_TAG}' no se encontró tras el build."
    exit 1
fi
IMAGE_SIZE=$(${CTR} images --format "{{.Size}}" "${IMAGE_TAG}" 2>/dev/null | head -1 || true)
echo "✓ Imagen disponible: ${IMAGE_TAG} (ID: ${IMAGE_ID}, Tamaño: ${IMAGE_SIZE})"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓  Build completado con éxito                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Imagen        : ${IMAGE_TAG}"
echo "  Runtime       : ${CTR}"
echo ""
echo "  Siguiente paso:"
echo "    Container → ./02-deploy-container.sh"
echo "    OCP       → ./01-build-image-ocp.sh   (build en cluster)"
echo ""
