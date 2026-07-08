#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# simulate-purchases-wave2.sh — Wave 2 de compras simuladas (vía API REST)
#
# Vende ~450 entradas adicionales sobre las ~300 ya vendidas en el arranque,
# dejando el evento con ~750 de 1000 entradas vendidas.
#
#   · 400 GENERAL  (80 compradores × 5 entradas)
#   ·  50 VIP      (10 compradores × 5 entradas)
#
# Uso:
#   ./scripts/simulate-purchases-wave2.sh [BASE_URL]
#   BASE_URL por defecto: http://localhost:8080/f1-sales-tickets
# -----------------------------------------------------------------------------
set -euo pipefail

BASE_URL="${1:-${API_BASE_URL:-http://localhost:8080/f1-sales-tickets}}"
PURCHASES_URL="${BASE_URL}/api/purchases"

echo "============================================================"
echo " simulate-purchases-wave2.sh (vía API REST)"
echo " Endpoint : ${PURCHASES_URL}"
echo " Simulando ~450 ventas (400 GENERAL + 50 VIP)"
echo "============================================================"

# ---------------------------------------------------------------------------
# Función: crear una compra vía POST /api/purchases
# Args: $1=nombre  $2=email  $3=telefono  $4=cantidad  $5=tipo
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
# 1. Compras GENERAL — 80 compradores × 5 entradas = 400 entradas
# ---------------------------------------------------------------------------
echo ""
echo "→ Insertando 80 compras GENERAL (5 entradas c/u = 400)..."

NOMBRES_GENERAL=(
    "Alfonso Mora" "Blanca Serrano" "César Herrero" "Diana Vega" "Ernesto Calvo"
    "Fátima Benito" "Gregorio Soto" "Helena Arias" "Ignacio Luna" "Julia Méndez"
    "Kevin Bravo" "Leire Gallego" "Manuel Rojas" "Nadia Fuentes" "Omar Pascual"
    "Paloma Crespo" "Quintín Lozano" "Rebeca Nieto" "Salvador Moya" "Tamara Rubio"
    "Ulises Pardo" "Valentina Cruz" "Walter Reina" "Ximena Agudo" "Yolanda Pedraza"
    "Zacarías Baena" "Adrián Segura" "Beatriz Montes" "Carlos Espinosa" "Dolores Toro"
    "Eduardo Mena" "Francisca Bernal" "Guillermo Tejada" "Hortensia Plata" "Íñigo Vélez"
    "Jacinta Barrera" "Lamberto Cano" "Milagros Ríos" "Narciso Bosch" "Olga Camacho"
    "Patricio Guzmán" "Queralt Roca" "Rosario Cuenca" "Santiago Varela" "Trinidad Soler"
    "Ubaldo Marín" "Virtudes Palacios" "Wilfredo Ojeda" "Xenia Montoya" "Yago Aranda"
    "Zoraida Casas" "Abel Córdoba" "Bibiana Esteve" "Camilo Solano" "Delia Pizarro"
    "Emigdio Tapia" "Fernanda Acosta" "Gilberto Fuenmayor" "Herminia Zárate" "Isidro Ponce"
    "Josefa Linares" "Klarissa Ibáñez" "Leandro Quintero" "Macaria Salazar" "Norberto Ovalle"
    "Odilia Bermúdez" "Primitivo Chacón" "Rosalba Fajardo" "Timoteo Granados" "Ursula Henao"
    "Vidal Jaramillo" "Wenceslao Londoño" "Xiomara Meza" "Yasmin Narváez" "Zósimo Ospina"
    "Amelia Pineda" "Bonifacio Quiroga" "Catalina Restrepo" "Donato Sandoval" "Evangelina Tobón"
)

gen_ok=0
for n in $(seq 0 79); do
    nombre="${NOMBRES_GENERAL[$n]}"
    email="wave2.g$((n+1))@email.com"
    telefono="6$(printf '%08d' $((30000000 + (n+1) * 11)))"
    comprar "${nombre}" "${email}" "${telefono}" 5 "GENERAL" && gen_ok=$((gen_ok + 1))
done

echo "✓ Compras GENERAL wave 2: ${gen_ok}/80"

# ---------------------------------------------------------------------------
# 2. Compras VIP — 10 compradores × 5 entradas = 50 entradas
# ---------------------------------------------------------------------------
echo ""
echo "→ Insertando 10 compras VIP (5 entradas c/u = 50)..."

NOMBRES_VIP=(
    "Augusto Ballester" "Brunilda Fuster" "Casimiro Alemany" "Desamparados Moll"
    "Epifanio Sastre" "Florentina Colom" "Gumersindo Esteve" "Honoria Ferragut"
    "Ildefonso Alomar" "Joaquina Bonet"
)

vip_ok=0
for n in $(seq 0 9); do
    nombre="${NOMBRES_VIP[$n]}"
    email="wave2.vip$((n+1))@premium.com"
    telefono="6$(printf '%08d' $((40000000 + (n+1) * 17)))"
    comprar "${nombre}" "${email}" "${telefono}" 5 "VIP" && vip_ok=$((vip_ok + 1))
done

echo "✓ Compras VIP wave 2: ${vip_ok}/10"

# ---------------------------------------------------------------------------
# 3. Resumen
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Resumen tras wave 2 (vía API)"
echo "   GENERAL compras OK : ${gen_ok}/80  (entradas: $((gen_ok * 5)))"
echo "   VIP     compras OK : ${vip_ok}/10  (entradas: $((vip_ok * 5)))"
echo ""
echo " Estado del evento:"
curl -s "${BASE_URL}/api/events/availability" | \
    (command -v jq >/dev/null 2>&1 \
        && jq -r '.data | "   Vendidas: \(.entradasVendidas) / \(.capacidadTotal)  (\(.porcentajeVendido | floor)%)"' \
        || cat)
echo ""
echo "============================================================"
