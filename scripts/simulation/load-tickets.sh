#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# load-tickets.sh — Carga tickets adicionales a través de la API REST
#
# Uso:
#   ./scripts/load-tickets.sh [BASE_URL]
#
#   BASE_URL por defecto: http://localhost:8080/f1-tickets
#
# Añade:
#   - 48  entradas VIP     (secciones V3..V4, 24 asientos cada una)
#   - 167 entradas GENERAL (secciones G9..G16, 20 asientos por sección + 7 en G17)
#
# Idempotente: la API responde 200 si el asiento ya existe (ON CONFLICT DO NOTHING).
# Requiere: curl, jq (opcional para validar respuestas)
# -----------------------------------------------------------------------------
set -euo pipefail

# ---------------------------------------------------------------------------
# Detección de arquitectura/SO para seleccionar el generador de aleatorios:
#   macOS (Darwin / arm64 o amd64) → jot -r
#   Linux (amd64 / arm64 / cualquier) → shuf
# ---------------------------------------------------------------------------
_OS="$(uname -s)"
_ARCH="$(uname -m)"

_rand() {
    local lo="$1" hi="$2"
    if [ "${_OS}" = "Darwin" ]; then
        jot -r 1 "${lo}" "${hi}"
    else
        shuf -i "${lo}-${hi}" -n 1
    fi
}

BASE_URL="${1:-${API_BASE_URL:-http://localhost:8080/f1-tickets}}"
EVENT_ID="${EVENT_ID:-F1-2026-ESP}"
TICKETS_URL="${BASE_URL}/api/tickets"

echo "============================================================"
echo " load-tickets.sh (vía API REST)"
echo " Endpoint : ${TICKETS_URL}"
echo " Evento   : ${EVENT_ID}"
echo "============================================================"

# Función auxiliar: crear un ticket vía POST /api/tickets
# Args: $1=tipo  $2=asiento  $3=seccion
post_ticket() {
    local tipo="$1"
    local asiento="$2"
    local seccion="$3"

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${TICKETS_URL}" \
        -H "Content-Type: application/json" \
        -d "{\"eventId\":\"${EVENT_ID}\",\"tipo\":\"${tipo}\",\"asiento\":\"${asiento}\",\"seccion\":\"${seccion}\"}")

    if [ "${http_code}" != "201" ] && [ "${http_code}" != "200" ]; then
        echo "  ✗ Error HTTP ${http_code} — ${tipo} asiento=${asiento}"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# 1. Tickets VIP — 48 asientos
#    Secciones V3 y V4, 24 asientos por sección (filas A-D, 6 asientos/fila)
#    Precio: 450.00 (fijado en el enum TipoEntrada)
# -----------------------------------------------------------------------------
echo ""
echo "→ Cargando 48 entradas VIP (secciones V3, V4)..."

vip_ok=0
for seccion_num in 3 4; do
    seccion="V${seccion_num}"
    for fila_num in 1 2 3 4; do
        fila=$(printf "\\x$(printf '%02x' $((64 + fila_num)))")   # A=1 → A, etc.
        for asiento_num in $(seq 1 6); do
            asiento="${seccion}-${fila}$(printf '%02d' "${asiento_num}")"
            post_ticket "VIP" "${asiento}" "${seccion}"
            vip_ok=$((vip_ok + 1))
        done
    done
done

echo "✓ Entradas VIP enviadas a la API: ${vip_ok}"

# -----------------------------------------------------------------------------
# 2. Tickets GENERAL — 160 asientos
#    Secciones G9..G16, 20 asientos por sección (filas A-D, 5 asientos/fila)
# -----------------------------------------------------------------------------
echo ""
echo "→ Cargando 160 entradas GENERAL (secciones G9..G16)..."

gen_ok=0
for seccion_num in $(seq 9 16); do
    seccion="G${seccion_num}"
    for fila_num in 1 2 3 4; do
        fila=$(printf "\\x$(printf '%02x' $((64 + fila_num)))")
        for asiento_num in $(seq 1 5); do
            asiento="${seccion}-${fila}$(printf '%02d' "${asiento_num}")"
            post_ticket "GENERAL" "${asiento}" "${seccion}"
            gen_ok=$((gen_ok + 1))
        done
    done
done

echo "✓ Entradas GENERAL G9-G16 enviadas a la API: ${gen_ok}"

# -----------------------------------------------------------------------------
# 3. Tickets GENERAL — 7 asientos extra
#    Sección G17, fila A, asientos 01-07
# -----------------------------------------------------------------------------
echo ""
echo "→ Cargando 7 entradas GENERAL (sección G17, fila A)..."

g17_ok=0
for asiento_num in $(seq 1 7); do
    asiento="G17-A$(printf '%02d' "${asiento_num}")"
    post_ticket "GENERAL" "${asiento}" "G17"
    g17_ok=$((g17_ok + 1))
done

echo "✓ Entradas GENERAL G17 enviadas a la API: ${g17_ok}"

# -----------------------------------------------------------------------------
# 4. Resumen final
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Resumen de carga (vía API)"
echo "   VIP       enviados : ${vip_ok}"
echo "   GENERAL   enviados : $((gen_ok + g17_ok))"
echo "   TOTAL     enviados : $((vip_ok + gen_ok + g17_ok))"
echo ""
echo " Disponibilidad actual:"
curl -s "${BASE_URL}/api/tickets/availability" | \
    (command -v jq >/dev/null 2>&1 \
        && jq -r '.data[] | "   \(.tipo): \(.disponibles) disponibles"' \
        || cat)
echo ""
echo "============================================================"
