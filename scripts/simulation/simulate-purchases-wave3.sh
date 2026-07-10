#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# simulate-purchases-wave3.sh — Wave 3 de compras simuladas / SOLD OUT (vía API)
#
# Ejecutar después de wave 2.
# Vende las ~250 entradas restantes de las 1000 originales del seed,
# dejando el evento COMPLETAMENTE AGOTADO (1000/1000).
#
#   · 200 GENERAL  (40 compradores × 5 entradas)
#   · 100 VIP      (20 compradores × 5 entradas)
#
# Uso:
#   ./scripts/simulate-purchases-wave3.sh [BASE_URL]
#   BASE_URL por defecto: http://localhost:8080/f1-tickets
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
PURCHASES_URL="${BASE_URL}/api/purchases"

echo "============================================================"
echo " simulate-purchases-wave3.sh — SOLD OUT (vía API REST)"
echo " Endpoint : ${PURCHASES_URL}"
echo " Agotando las 1000 entradas del evento"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# Verificar que la API está accesible antes de empezar
# ---------------------------------------------------------------------------
echo "→ Verificando conexión con la API..."
for intento in 1 2 3; do
    http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${BASE_URL}/api/events/availability" 2>/dev/null || echo "000")
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
        echo "  Levántala con:  ./run-container.sh"
        echo "  Luego vuelve a ejecutar este script, o pasa la URL como argumento:"
        echo "    $0 <BASE_URL>"
        echo ""
        exit 1
    fi
    echo "  Intento ${intento}/3 fallido (HTTP ${http_status}), reintentando en 3s..."
    sleep 3
done

# Verificar estado actual vía API
echo ""
echo " Estado actual del evento:"
resp_event=$(curl -s "${BASE_URL}/api/events/availability")
if command -v jq >/dev/null 2>&1; then
    echo "${resp_event}" | jq -r '.data | "   Vendidas : \(.entradasVendidas) / \(.capacidadTotal)\n   Agotado  : \(.agotado)"'
else
    echo "${resp_event}"
fi
echo ""

# Guardia: si ya está agotado, no hacer nada
if command -v jq >/dev/null 2>&1; then
    agotado=$(echo "${resp_event}" | jq -r '.data.agotado')
else
    agotado=$(echo "${resp_event}" | grep -o '"agotado":[a-z]*' | grep -o '[a-z]*$')
fi
if [ "${agotado}" = "true" ]; then
    echo "⚠ El evento ya está agotado. No se insertan más compras."
    exit 0
fi

# ---------------------------------------------------------------------------
# Función: crear una compra vía POST /api/purchases
# ---------------------------------------------------------------------------
comprar() {
    local nombre="$1"
    local email="$2"
    local telefono="$3"
    local cantidad="$4"
    local tipo="$5"

    local body
    body=$(printf '{"eventId":"F1-2026-ESP","nombreComprador":"%s","email":"%s","telefono":"%s","cantidadEntradas":%d,"tipoEntrada":"%s"}' \
        "${nombre}" "${email}" "${telefono}" "${cantidad}" "${tipo}")

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${PURCHASES_URL}" \
        -H "Content-Type: application/json" \
        -d "${body}")

    if [ "${http_code}" != "201" ]; then
        echo "  ✗ Error HTTP ${http_code} — ${nombre} (${cantidad}x ${tipo})"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# 1. Compras GENERAL — 40 compradores × 5 entradas = 200 entradas
# ---------------------------------------------------------------------------
echo "→ Insertando 40 compras GENERAL (5 entradas c/u = 200)..."

NOMBRES_GENERAL=(
    "Abelardo Cifuentes" "Benedicta Urrutia" "Candelario Peñaranda" "Deifilia Zambrano"
    "Eladio Murillo" "Felícitas Chávez" "Gaudencio Bermejo" "Humbelina Alcántara"
    "Ireneo Ballesteros" "Jacoba Chinchilla" "Ladislao Echevarría" "Maravillas Fontecha"
    "Nemesio Guardiola" "Obdulia Hurtado" "Plácido Izquierdo" "Quirino Jaén"
    "Restituta Kardas" "Sinforoso Larrañaga" "Telesfora Marchena" "Urbano Novoa"
    "Valentín Oropeza" "Wendy Pacheco" "Xifré Quijano" "Yolanda Recuero" "Zenón Salcedo"
    "Ágata Taboada" "Bienvenido Ureña" "Celestino Valdés" "Diamantina Wendell"
    "Emigdio Ximeño" "Filomena Yepes" "Gaspar Zapata" "Herculano Abad" "Inmaculada Becerra"
    "Jenaro Castellano" "Lucrecio Días" "Macrina Espinoza" "Norberto Ferri"
    "Obispo Galán" "Primitiva Heras"
)

gen_ok=0
for n in $(seq 0 39); do
    nombre="${NOMBRES_GENERAL[$n]}"
    email="wave3.g$((n+1))@email.com"
    telefono="6$(printf '%08d' $((50000000 + (n+1) * 19)))"
    comprar "${nombre}" "${email}" "${telefono}" 5 "GENERAL" && gen_ok=$((gen_ok + 1))
done

echo "✓ Compras GENERAL wave 3: ${gen_ok}/40"

# ---------------------------------------------------------------------------
# 2. Compras VIP — 20 compradores × 5 entradas = 100 entradas
# ---------------------------------------------------------------------------
echo ""
echo "→ Insertando 20 compras VIP (5 entradas c/u = 100)..."

NOMBRES_VIP=(
    "Arcadio Benítez" "Brígida Cantero" "Calixto Domínguez" "Demetria Encinas"
    "Eustaquio Figueroa" "Florinda Garrido" "Gervasio Hidalgo" "Higinia Ibarra"
    "Ireneo Jerez" "Jucunda Kepler" "Liberato Lago" "Marcela Morales"
    "Natalio Ñoño" "Obscura Obregón" "Pancracio Pareja" "Querubín Quirós"
    "Rosendo Riquelme" "Serapia Siguenza" "Teodolindo Trujillo" "Ulderico Ugarte"
)

vip_ok=0
for n in $(seq 0 19); do
    nombre="${NOMBRES_VIP[$n]}"
    email="wave3.vip$((n+1))@premium.com"
    telefono="6$(printf '%08d' $((60000000 + (n+1) * 23)))"
    comprar "${nombre}" "${email}" "${telefono}" 5 "VIP" && vip_ok=$((vip_ok + 1))
done

echo "✓ Compras VIP wave 3: ${vip_ok}/20"

# ---------------------------------------------------------------------------
# 3. Resumen final — SOLD OUT
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " *** EVENTO AGOTADO — SOLD OUT ***"
echo ""
echo " Resumen wave 3 (vía API):"
echo "   GENERAL compras OK : ${gen_ok}/40  (entradas: $((gen_ok * 5)))"
echo "   VIP     compras OK : ${vip_ok}/20  (entradas: $((vip_ok * 5)))"
echo ""
echo " Estado final del evento:"
curl -s "${BASE_URL}/api/events/availability" | \
    (command -v jq >/dev/null 2>&1 \
        && jq -r '.data | "   Vendidas: \(.entradasVendidas) / \(.capacidadTotal)  (\(.porcentajeVendido | floor)%)\n   Agotado : \(.agotado)"' \
        || cat)
echo ""
echo " Estadísticas de compras:"
curl -s "${BASE_URL}/api/purchases/stats" | \
    (command -v jq >/dev/null 2>&1 \
        && jq -r '.data | "   Total compras          : \(.totalCompras)\n   Total entradas vendidas: \(.totalEntradasVendidas)\n   Ingresos totales       : €\(.ingresoTotal)"' \
        || cat)
echo ""
echo "============================================================"
