#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run-container.sh — build + ciclo de vida de f1-sales-tickets
# Stack: WildFly 18 + PostgreSQL 15 (monolito local)
#
# Auto-detecta:
#   · Runtime   — podman (preferido) o docker
#   · Arquitectura — arm64 (Apple Silicon / ARM) o amd64 (x86_64)
#
# Uso:
#   ./run-container.sh                  — build + run (default)
#   ./run-container.sh build            — construir imagen nativa
#   ./run-container.sh run              — arrancar contenedor (crea si no existe)
#   ./run-container.sh stop             — detener contenedor
#   ./run-container.sh destroy          — borrar contenedor y volumen persistente
#   ./run-container.sh logs             — seguir logs en tiempo real
#   ./run-container.sh multiarch-push   — construir manifest multi-arch y publicar
#                                         (requiere IMAGE_REGISTRY definido)
# ---------------------------------------------------------------------------
set -euo pipefail

IMAGE_NAME="f1-sales-tickets"
CONTAINER_NAME="f1-tickets"
# Named volume para persistir datos de PostgreSQL entre reinicios.
# Corresponde a PGSQL_DATA del Containerfile: /var/lib/pgsql/15/data
PG_VOLUME="f1-tickets-pgdata"

# Registro de destino para el push multi-arch (override con variable de entorno)
IMAGE_REGISTRY="${IMAGE_REGISTRY:-}"

# ---------------------------------------------------------------------------
# 1. Detectar runtime: podman tiene prioridad sobre docker
# ---------------------------------------------------------------------------
if command -v podman &>/dev/null; then
    CTR="podman"
elif command -v docker &>/dev/null; then
    CTR="docker"
else
    echo "✗ Ni podman ni docker encontrados. Instala uno de ellos." >&2
    exit 1
fi
echo "→ Runtime detectado: ${CTR}"

# ---------------------------------------------------------------------------
# 2. Detectar arquitectura nativa y seleccionar --platform
# ---------------------------------------------------------------------------
NATIVE_ARCH=$(uname -m)
case "${NATIVE_ARCH}" in
    arm64|aarch64) PLATFORM="linux/arm64" ;;
    x86_64|amd64)  PLATFORM="linux/amd64" ;;
    *)
        echo "⚠ Arquitectura desconocida '${NATIVE_ARCH}', usando linux/amd64 por defecto." >&2
        PLATFORM="linux/amd64"
        ;;
esac
echo "→ Arquitectura detectada: ${NATIVE_ARCH} → --platform ${PLATFORM}"

# ---------------------------------------------------------------------------
# Funciones
# ---------------------------------------------------------------------------

build() {
    echo "→ Construyendo imagen ${IMAGE_NAME} para ${PLATFORM}..."
    ${CTR} build \
        --platform "${PLATFORM}" \
        -f Containerfile \
        -t "${IMAGE_NAME}" \
        .
    echo "✓ Imagen construida: ${IMAGE_NAME}"
}

run() {
    # Crear volumen si no existe
    ${CTR} volume inspect "${PG_VOLUME}" &>/dev/null \
        || ${CTR} volume create "${PG_VOLUME}"

    # Si el contenedor ya existe (detenido), arrancarlo; si no, crearlo
    if ${CTR} container inspect "${CONTAINER_NAME}" &>/dev/null; then
        echo "→ Arrancando contenedor existente ${CONTAINER_NAME}..."
        ${CTR} start "${CONTAINER_NAME}"
    else
        echo "→ Creando y arrancando contenedor ${CONTAINER_NAME}..."
        ${CTR} run -d \
            --name "${CONTAINER_NAME}" \
            -p 8080:8080 \
            -p 9990:9990 \
            -p 5432:5432 \
            -e PGSQL_USER=appuser \
            -e PGSQL_PASSWORD=apppassword \
            -e PGSQL_DB=appdb \
            -v "${PG_VOLUME}:/var/lib/pgsql/15/data:Z" \
            "${IMAGE_NAME}"
    fi

    echo "✓ Contenedor ${CONTAINER_NAME} en ejecución."
    echo "  Web UI  : http://localhost:8080/f1-tickets"
    echo "  REST API: http://localhost:8080/f1-tickets/api/events"
    echo "  Logs    : ${CTR} logs -f ${CONTAINER_NAME}"
}

stop() {
    echo "→ Deteniendo ${CONTAINER_NAME}..."
    ${CTR} stop "${CONTAINER_NAME}" && echo "✓ Detenido."
}

destroy() {
    echo "→ Eliminando contenedor y volumen..."
    ${CTR} rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    ${CTR} volume rm "${PG_VOLUME}" 2>/dev/null || true
    echo "✓ Eliminado. El próximo 'run' inicializará la base de datos desde cero."
}

logs() {
    ${CTR} logs -f "${CONTAINER_NAME}"
}

# ---------------------------------------------------------------------------
# multiarch-push — construye un manifest multi-arch (amd64 + arm64) y lo
# publica en el registry indicado por IMAGE_REGISTRY.
#
# Requiere:
#   export IMAGE_REGISTRY=registry.example.com/myorg
#
# Con podman usa 'podman manifest'; con docker usa 'docker buildx'.
# ---------------------------------------------------------------------------
multiarch_push() {
    if [[ -z "${IMAGE_REGISTRY}" ]]; then
        echo "✗ Define IMAGE_REGISTRY antes de ejecutar multiarch-push." >&2
        echo "  Ejemplo: IMAGE_REGISTRY=quay.io/myorg ./run-container.sh multiarch-push" >&2
        exit 1
    fi

    FULL_IMAGE="${IMAGE_REGISTRY}/${IMAGE_NAME}:latest"
    echo "→ Construyendo manifest multi-arch para: ${FULL_IMAGE}"

    if [[ "${CTR}" == "podman" ]]; then
        # Eliminar manifest previo si existe
        podman manifest rm "${FULL_IMAGE}" 2>/dev/null || true
        podman build \
            --platform linux/amd64,linux/arm64 \
            --manifest "${FULL_IMAGE}" \
            -f Containerfile \
            .
        echo "→ Publicando manifest en ${IMAGE_REGISTRY}..."
        podman manifest push "${FULL_IMAGE}" "docker://${FULL_IMAGE}"
    else
        # Docker requiere buildx con un builder que soporte multi-plataforma
        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            -f Containerfile \
            -t "${FULL_IMAGE}" \
            --push \
            .
    fi

    echo "✓ Imagen multi-arch publicada: ${FULL_IMAGE}"
}

# ---------------------------------------------------------------------------
# Punto de entrada
# ---------------------------------------------------------------------------
case "${1:-}" in
    build)          build ;;
    run)            run ;;
    stop)           stop ;;
    destroy)        destroy ;;
    logs)           logs ;;
    multiarch-push) multiarch_push ;;
    *)
        build
        run
        ;;
esac
