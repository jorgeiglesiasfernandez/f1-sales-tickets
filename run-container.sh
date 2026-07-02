#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Helper to build and run the AlmaLinux 8 container
# Stack: WildFly 18 + PostgreSQL 15 (local monolith)
#
# Automatically detects podman or docker (podman takes priority).
#
# Usage:
#   ./run-container.sh           — build + run
#   ./run-container.sh build     — build image only
#   ./run-container.sh run       — start container (create if needed)
#   ./run-container.sh stop      — stop the running container
#   ./run-container.sh destroy   — remove container and persistent volume
#   ./run-container.sh logs      — follow container logs
# ---------------------------------------------------------------------------
set -euo pipefail

IMAGE_NAME="f1-sales-tickets"
CONTAINER_NAME="f1-tickets"
# Named volume to persist PostgreSQL data across restarts.
# Maps to PGSQL_DATA defined in the Dockerfile: /var/lib/pgsql/15/data
PG_VOLUME="f1-tickets-pgdata"

# ---------------------------------------------------------------------------
# Detect container runtime: podman takes priority over docker
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
# Commands
# ---------------------------------------------------------------------------

build() {
    echo "→ Building image ${IMAGE_NAME}..."
    ${CTR} build -t "${IMAGE_NAME}" .
    echo "✓ Image built: ${IMAGE_NAME}"
}

run() {
    # Create the volume if it does not exist
    ${CTR} volume inspect "${PG_VOLUME}" &>/dev/null \
        || ${CTR} volume create "${PG_VOLUME}"

    # If the container already exists (stopped), start it; otherwise create it
    if ${CTR} container inspect "${CONTAINER_NAME}" &>/dev/null; then
        echo "→ Starting existing container ${CONTAINER_NAME}..."
        ${CTR} start "${CONTAINER_NAME}"
    else
        echo "→ Creating and starting container ${CONTAINER_NAME}..."
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

    echo "✓ Container ${CONTAINER_NAME} is running."
    echo "  Web UI  : http://localhost:8080/f1-tickets"
    echo "  REST API: http://localhost:8080/f1-tickets/api/events"
    echo "  Logs    : ${CTR} logs -f ${CONTAINER_NAME}"
}

stop() {
    echo "→ Stopping ${CONTAINER_NAME}..."
    ${CTR} stop "${CONTAINER_NAME}" && echo "✓ Stopped."
}

destroy() {
    echo "→ Removing container and volume..."
    ${CTR} rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    ${CTR} volume rm "${PG_VOLUME}" 2>/dev/null || true
    echo "✓ Removed. The next 'run' will initialise the database from scratch."
}

logs() {
    ${CTR} logs -f "${CONTAINER_NAME}"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
case "${1:-}" in
    build)   build ;;
    run)     run ;;
    stop)    stop ;;
    destroy) destroy ;;
    logs)    logs ;;
    *)
        build
        run
        ;;
esac
