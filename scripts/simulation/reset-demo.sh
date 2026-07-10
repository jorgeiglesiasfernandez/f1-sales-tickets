#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# reset-demo.sh — Resetea todas las compras vía REST API y deja el evento
#                 listo para empezar una nueva demostración desde cero.
#
# Llama a: DELETE /api/purchases
#
# El endpoint ejecuta en una única transacción atómica:
#   1. Borra purchase_tickets
#   2. Borra purchases
#   3. Libera todos los tickets  (disponible = TRUE)
#   4. Resetea events.entradas_vendidas = 0
#
# Uso:
#   ./scripts/simulation/reset-demo.sh [BASE_URL]
#   BASE_URL por defecto: http://localhost:8080/f1-tickets
#
# Ejemplos:
#   # Entorno local
#   ./scripts/simulation/reset-demo.sh
#
#   # OCP
#   ./scripts/simulation/reset-demo.sh https://f1-tickets-f1-tickets.apps.<cluster>/f1-tickets
#
#   # Con variable de entorno
#   API_BASE_URL=https://f1-tickets-f1-tickets.apps.<cluster>/f1-tickets \
#     ./scripts/simulation/reset-demo.sh
# -----------------------------------------------------------------------------
set -euo pipefail

BASE_URL="${1:-${API_BASE_URL:-http://localhost:8080/f1-tickets}}"
PURCHASES_URL="${BASE_URL}/api/purchases"
AVAILABILITY_URL="${BASE_URL}/api/events/availability"

echo "========================================================================"
echo " reset-demo.sh — Reset de compras vía API REST"
echo " Endpoint : ${PURCHASES_URL}"
echo "========================================================================"
echo ""

# -----------------------------------------------------------------------------
# Verificar que la API está accesible
# -----------------------------------------------------------------------------
echo "→ Verificando conexión con la API..."
for intento in 1 2 3; do
    http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
        "${AVAILABILITY_URL}" 2>/dev/null || echo "000")
    if [ "${http_status}" = "200" ]; then
        echo "✓ API accesible (HTTP ${http_status})"
        break
    fi
    if [ "${intento}" -eq 3 ]; then
        echo ""
        echo "✗ No se puede conectar con la API en: ${BASE_URL}"
        echo "  HTTP status: ${http_status}"
        echo ""
        echo "  ¿Está la aplicación en ejecución?"
        echo "  Local : ./deploy/local/run.sh"
        echo "  OCP   : ./deploy/ocp/deploy.sh status"
        echo ""
        exit 1
    fi
    echo "  Intento ${intento}/3 fallido (HTTP ${http_status}), reintentando en 3s..."
    sleep 3
done
echo ""

# -----------------------------------------------------------------------------
# Estado ANTES del reset
# -----------------------------------------------------------------------------
echo "→ Estado ANTES del reset:"
before=$(curl -s "${AVAILABILITY_URL}")
if command -v jq >/dev/null 2>&1; then
    echo "${before}" | jq -r \
        '.data | "   Vendidas   : \(.entradasVendidas) / \(.capacidadTotal) (\(.porcentajeVendido | floor)%)\n   Disponibles: \(.entradasDisponibles)"'
else
    echo "${before}" | grep -o '"entradasVendidas":[0-9]*\|"capacidadTotal":[0-9]*\|"entradasDisponibles":[0-9]*' \
        | tr '\n' '  '
    echo ""
fi
echo ""

# -----------------------------------------------------------------------------
# Ejecutar el reset
# -----------------------------------------------------------------------------
echo "→ Ejecutando reset (DELETE ${PURCHASES_URL})..."
response=$(curl -s -w "\n%{http_code}" -X DELETE "${PURCHASES_URL}" \
    -H "Content-Type: application/json")

body=$(echo "${response}" | head -n -1)
http_code=$(echo "${response}" | tail -n 1)

if [ "${http_code}" != "200" ]; then
    echo ""
    echo "✗ Error al ejecutar el reset. HTTP ${http_code}"
    echo "  Respuesta: ${body}"
    exit 1
fi

echo "✓ Reset ejecutado correctamente (HTTP ${http_code})"
echo ""

# Mostrar detalle del resultado si hay jq
if command -v jq >/dev/null 2>&1; then
    echo "  Detalle de operaciones:"
    echo "${body}" | jq -r '
        .data |
        "   purchase_tickets borrados : \(.purchaseTicketsDeleted)\n" +
        "   purchases borradas        : \(.purchasesDeleted)\n" +
        "   tickets liberados         : \(.ticketsReleased)\n" +
        "   contador evento reseteado : \(.eventCounterReset)"'
fi
echo ""

# -----------------------------------------------------------------------------
# Estado DESPUÉS del reset
# -----------------------------------------------------------------------------
echo "→ Estado DESPUÉS del reset:"
after=$(curl -s "${AVAILABILITY_URL}")
if command -v jq >/dev/null 2>&1; then
    echo "${after}" | jq -r \
        '.data | "   Vendidas   : \(.entradasVendidas) / \(.capacidadTotal) (\(.porcentajeVendido | floor)%)\n   Disponibles: \(.entradasDisponibles)"'
else
    echo "${after}" | grep -o '"entradasVendidas":[0-9]*\|"capacidadTotal":[0-9]*\|"entradasDisponibles":[0-9]*' \
        | tr '\n' '  '
    echo ""
fi

echo ""
echo "========================================================================"
echo " ✓ Demo reseteada. El evento está listo para empezar de nuevo."
echo "   Continúa la simulación con:"
echo "   ./scripts/simulation/simulate-purchases-wave2.sh ${BASE_URL}"
echo "   ./scripts/simulation/simulate-purchases-random.sh ${BASE_URL}"
echo "========================================================================"
