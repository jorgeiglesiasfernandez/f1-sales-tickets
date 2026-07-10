#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# simulate-purchases-random.sh — Compras aleatorias continuas (vía API REST)
#
# Simula compras de entradas de forma continua con intervalos aleatorios
# entre 2 y 10 minutos, usuarios aleatorios y cantidad aleatoria de 1 a 4
# entradas por compra, hasta agotar el aforo del evento.
#
# Uso:
#   ./scripts/simulate-purchases-random.sh [BASE_URL]
#   BASE_URL por defecto: http://localhost:8080/f1-tickets
#
# Variables de entorno opcionales:
#   EVENT_ID     — ID del evento (por defecto: F1-2026-ESP)
#   MIN_WAIT     — Espera mínima en segundos (por defecto: 120)
#   MAX_WAIT     — Espera máxima en segundos (por defecto: 600)
#   MIN_TICKETS  — Entradas mínimas por compra (por defecto: 1)
#   MAX_TICKETS  — Entradas máximas por compra (por defecto: 4)
# -----------------------------------------------------------------------------
set -euo pipefail

# ---------------------------------------------------------------------------
# Detección de arquitectura/SO para seleccionar el generador de aleatorios:
#   macOS (Darwin / arm64 o amd64) → jot -r
#   Linux (amd64 / arm64 / cualquier) → shuf
# ---------------------------------------------------------------------------
_OS="$(uname -s)"
_ARCH="$(uname -m)"
echo "→ Plataforma detectada: ${_OS} / ${_ARCH}"

_rand() {
    # _rand MIN MAX → entero aleatorio en [MIN, MAX]
    local lo="$1" hi="$2"
    if [ "${_OS}" = "Darwin" ]; then
        jot -r 1 "${lo}" "${hi}"
    else
        shuf -i "${lo}-${hi}" -n 1
    fi
}

BASE_URL="${1:-${API_BASE_URL:-http://localhost:8080/f1-tickets}}"
: "${EVENT_ID:=F1-2026-ESP}"
: "${MIN_WAIT:=5}"
: "${MAX_WAIT:=15}"
: "${MIN_TICKETS:=1}"
: "${MAX_TICKETS:=4}"

PURCHASES_URL="${BASE_URL}/api/purchases"
AVAILABILITY_URL="${BASE_URL}/api/tickets/availability"
EVENT_URL="${BASE_URL}/api/events/availability"

# -----------------------------------------------------------------------------
# Pool de 100 compradores aleatorios con nombre
# -----------------------------------------------------------------------------
NOMBRES=(
    "Alejandro García"    "Beatriz López"      "Carlos Martínez"   "Diana Fernández"
    "Emilio González"     "Fátima Rodríguez"   "Gabriel Sánchez"   "Helena Pérez"
    "Ignacio Gómez"       "Julia Muñoz"        "Kevin Jiménez"     "Laura Díaz"
    "Miguel Moreno"       "Nuria Álvarez"      "Óscar Romero"      "Patricia López"
    "Quintín Torres"      "Raquel Flores"      "Sergio Ramos"      "Teresa Gil"
    "Urbano Ruiz"         "Valentina Castro"   "Wenceslao Ortega"  "Ximena Rubio"
    "Yolanda Morales"     "Zacarías Soto"      "Adrián Herrera"    "Blanca Medina"
    "César Vargas"        "Dolores Guerrero"   "Eduardo Mendoza"   "Francisca Iglesias"
    "Gonzalo Carrillo"    "Herminia Cano"      "Isidro Navarro"    "Jacinta Peña"
    "Lorenzo Domínguez"   "Macarena Vázquez"   "Narciso Ramos"     "Olga Serrano"
    "Pedro Blanco"        "Queralt Molina"     "Roberto Moreno"    "Sandra Suárez"
    "Tomás Delgado"       "Úrsula Ortiz"       "Víctor Castro"     "Wendy Rubio"
    "Xenia Jiménez"       "Yago Núñez"         "Zoraida Medina"    "Abel Herrero"
    "Bibiana Aguilar"     "Camilo Muñoz"       "Delia Reyes"       "Emigdio Vega"
    "Fernanda Fuentes"    "Gilberto Nieto"     "Hortensia Cruz"    "Isidro Cabrera"
    "Josefa Molina"       "Kiko Álvarez"       "Lola Bermúdez"     "Mario Paredes"
    "Nadia Espinosa"      "Octavio Ríos"       "Pilar Campos"      "Rogelio Santos"
    "Salomé Guerrero"     "Tadeo Vargas"       "Ursula Ibáñez"     "Virgilio Ponce"
    "Waldo Cortés"        "Ximara Gallego"     "Yolanda Reina"     "Zenón Carrasco"
    "Alfonso Mora"        "Blanca Serrano"     "César Herrero"     "Diana Vega"
    "Ernesto Calvo"       "Fátima Benito"      "Gregorio Soto"     "Helena Arias"
    "Ignacio Luna"        "Julia Méndez"       "Kevin Bravo"       "Leire Gallego"
    "Manuel Rojas"        "Nadia Fuentes"      "Omar Pascual"      "Paloma Crespo"
    "Quintín Lozano"      "Rebeca Nieto"       "Salvador Moya"     "Tamara Rubio"
)

NUM_COMPRADORES=${#NOMBRES[@]}

echo "========================================================================"
echo " simulate-purchases-random.sh (vía API REST)"
echo " Endpoint: ${PURCHASES_URL}"
echo " Evento  : ${EVENT_ID}"
echo " Espera  : ${MIN_WAIT}s – ${MAX_WAIT}s entre compras"
echo " Entradas: ${MIN_TICKETS} – ${MAX_TICKETS} por compra"
echo " Pool    : ${NUM_COMPRADORES} compradores disponibles"
echo "========================================================================"
echo ""

# -----------------------------------------------------------------------------
# Verificar que la API está accesible antes de empezar
# -----------------------------------------------------------------------------
echo "→ Verificando conexión con la API..."
for intento in 1 2 3; do
    http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${EVENT_URL}" 2>/dev/null || echo "000")
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
echo ""

# -----------------------------------------------------------------------------
# Función: obtener entradas disponibles del evento vía API
# Devuelve el número de entradas disponibles totales (entero, mínimo 0)
# -----------------------------------------------------------------------------
disponibles() {
    local resp
    resp=$(curl -s "${EVENT_URL}")
    local n
    if command -v jq >/dev/null 2>&1; then
        n=$(echo "${resp}" | jq -r '.data.entradasDisponibles // 0' 2>/dev/null)
    else
        n=$(echo "${resp}" | grep -o '"entradasDisponibles":[0-9]*' | grep -o '[0-9]*$')
    fi
    echo "${n:-0}"
}

# -----------------------------------------------------------------------------
# Función: realizar una compra vía POST /api/purchases
# Parámetros: $1=seq $2=nombre $3=cantidad $4=tipo
# -----------------------------------------------------------------------------
realizar_compra() {
    local seq="$1"
    local nombre="$2"
    local cantidad="$3"
    local tipo="$4"
    local email
    # Normalización de nombre sin iconv (tr elimina tildes y ñ básicos)
    email="rnd.$(echo "${nombre}" | tr '[:upper:]' '[:lower:]' | \
                  tr ' ' '.' | \
                  tr 'áàäâéèëêíìïîóòöôúùüûñç' 'aaaaeeeeiiiioooouuuunc' | \
                  tr -cd '[:alnum:].' ).${seq}@f1fans.com"
    # jot puede devolver decimales en macOS → printf fuerza entero
    local telefono="6$(printf '%d' "$(_rand 10000000 99999999)")"

    local body
    body=$(printf '{"eventId":"%s","nombreComprador":"%s","email":"%s","telefono":"%s","cantidadEntradas":%d,"tipoEntrada":"%s"}' \
        "${EVENT_ID}" "${nombre}" "${email}" "${telefono}" "${cantidad}" "${tipo}")

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${PURCHASES_URL}" \
        -H "Content-Type: application/json" \
        -d "${body}")

    if [ "${http_code}" = "201" ]; then
        echo "   ✓ Compra #${seq} registrada"
    elif [ "${http_code}" = "409" ]; then
        echo "   ⚠ Sin stock (409) — saltando compra #${seq}"
    else
        echo "   ✗ Error HTTP ${http_code} en compra #${seq}"
    fi
}

# -----------------------------------------------------------------------------
# Bucle principal
# -----------------------------------------------------------------------------
compra_seq=1

while true; do
    libre=$(disponibles)
    libre=${libre:-0}

    if [ "${libre}" -le 0 ]; then
        echo ""
        echo "========================================================================"
        echo " ✓ SOLD OUT — No quedan entradas disponibles para ${EVENT_ID}"
        curl -s "${EVENT_URL}" | \
            (command -v jq >/dev/null 2>&1 \
                && jq -r '.data | "   \(.entradasVendidas) / \(.capacidadTotal) vendidas"' \
                || cat)
        echo "========================================================================"
        exit 0
    fi

    # Seleccionar comprador aleatorio del pool
    idx_comp=$(_rand 0 $(( NUM_COMPRADORES - 1 )))
    nombre="${NOMBRES[$idx_comp]}"

    # Cantidad aleatoria, sin superar las disponibles
    max_compra=$(( MAX_TICKETS < libre ? MAX_TICKETS : libre ))
    if [ "${max_compra}" -lt "${MIN_TICKETS}" ]; then
        max_compra=${MIN_TICKETS}
    fi
    cantidad=$(_rand "${MIN_TICKETS}" "${max_compra}")

    # Tipo aleatorio: 70% GENERAL, 30% VIP
    rand_tipo=$(_rand 1 10)
    if [ "${rand_tipo}" -le 7 ]; then
        tipo="GENERAL"
    else
        tipo="VIP"
    fi

    echo "[$(date '+%H:%M:%S')] Compra #${compra_seq} | ${nombre} | ${cantidad}x ${tipo} | Disponibles: ${libre}"

    realizar_compra "${compra_seq}" "${nombre}" "${cantidad}" "${tipo}"

    compra_seq=$(( compra_seq + 1 ))

    # Comprobar si ya se agotaron tras la compra
    libre=$(disponibles)
    libre=${libre:-0}
    if [ "${libre}" -le 0 ]; then
        echo ""
        echo "========================================================================"
        echo " ✓ SOLD OUT — Última entrada vendida en la compra #$(( compra_seq - 1 ))"
        curl -s "${EVENT_URL}" | \
            (command -v jq >/dev/null 2>&1 \
                && jq -r '.data | "   \(.entradasVendidas) / \(.capacidadTotal) vendidas"' \
                || cat)
        echo "========================================================================"
        exit 0
    fi

    # Espera aleatoria
    wait_sec=$(_rand "${MIN_WAIT}" "${MAX_WAIT}")
    wait_min=$(( wait_sec / 60 ))
    wait_rem=$(( wait_sec % 60 ))
    echo "   → Próxima compra en ${wait_sec}s (~${wait_min}m${wait_rem}s)..."
    sleep "${wait_sec}"
done
