#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# simulate-purchases-random.sh — Compras aleatorias continuas
#
# Simula compras de entradas de forma continua con intervalos aleatorios
# entre 2 y 10 minutos, usuarios aleatorios y cantidad aleatoria de 1 a 4
# entradas por compra, hasta agotar el aforo del evento.
#
# Uso:
#   podman exec -it f1-tickets bash /scripts/simulate-purchases-random.sh
#   oc exec -n f1-tickets <pod> -- bash /scripts/simulate-purchases-random.sh
#
# Variables de entorno opcionales:
#   EVENT_ID     — ID del evento (por defecto: F1-2026-ESP)
#   MIN_WAIT     — Espera mínima en segundos (por defecto: 120)
#   MAX_WAIT     — Espera máxima en segundos (por defecto: 600)
#   MIN_TICKETS  — Entradas mínimas por compra (por defecto: 1)
#   MAX_TICKETS  — Entradas máximas por compra (por defecto: 4)
# -----------------------------------------------------------------------------
set -euo pipefail

: "${PGSQL_USER:=appuser}"
: "${PGSQL_PASSWORD:=apppassword}"
: "${PGSQL_DB:=appdb}"
: "${EVENT_ID:=F1-2026-ESP}"
: "${MIN_WAIT:=120}"
: "${MAX_WAIT:=600}"
: "${MIN_TICKETS:=1}"
: "${MAX_TICKETS:=4}"

PSQL="psql -v ON_ERROR_STOP=1 --username ${PGSQL_USER} --dbname ${PGSQL_DB}"

# -----------------------------------------------------------------------------
# Pool de 100 compradores aleatorios con nombre, email y teléfono
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

# Número total de compradores en el pool
NUM_COMPRADORES=${#NOMBRES[@]}

echo "========================================================================"
echo " simulate-purchases-random.sh"
echo " Evento  : ${EVENT_ID}"
echo " Espera  : ${MIN_WAIT}s – ${MAX_WAIT}s entre compras"
echo " Entradas: ${MIN_TICKETS} – ${MAX_TICKETS} por compra"
echo " Pool    : ${NUM_COMPRADORES} compradores disponibles"
echo "========================================================================"
echo ""

# -----------------------------------------------------------------------------
# Función: obtener entradas disponibles del evento
# -----------------------------------------------------------------------------
disponibles() {
    ${PSQL} -tAc "
        SELECT COUNT(*)
        FROM tickets
        WHERE event_id = '${EVENT_ID}' AND disponible = TRUE;"
}

# -----------------------------------------------------------------------------
# Función: realizar una compra
# Parámetros: $1=secuencia_compra $2=nombre $3=cantidad $4=tipo
# -----------------------------------------------------------------------------
realizar_compra() {
    local seq="$1"
    local nombre="$2"
    local cantidad="$3"
    local tipo="$4"
    local purchase_id="PUR-RND-$(date +%Y%m%d%H%M%S)-${seq}"
    local conf_id="CONF-RND-${seq}-$(shuf -i 1000-9999 -n 1)"
    local idx_nombre="${nombre// /-}"
    local email="rnd.$(echo "${nombre}" | tr '[:upper:]' '[:lower:]' | tr ' ' '.' | tr -d 'áéíóúñü').${seq}@f1fans.com"
    local telefono="6$(shuf -i 10000000-99999999 -n 1)"
    local precio_unit
    if [ "${tipo}" = "VIP" ]; then
        precio_unit=450
    else
        precio_unit=150
    fi
    local precio_total=$(( cantidad * precio_unit ))

    ${PSQL} <<SQL
DO \$\$
DECLARE
    v_tickets TEXT[];
    v_ticket  TEXT;
    i         INT;
BEGIN
    -- Obtener tickets disponibles del tipo solicitado
    SELECT ARRAY(
        SELECT id FROM tickets
        WHERE event_id = '${EVENT_ID}'
          AND tipo     = '${tipo}'
          AND disponible = TRUE
        ORDER BY RANDOM()
        LIMIT ${cantidad}
    ) INTO v_tickets;

    -- Si no hay suficientes del tipo solicitado, abortar silenciosamente
    IF array_length(v_tickets, 1) IS NULL OR array_length(v_tickets, 1) < ${cantidad} THEN
        RAISE NOTICE 'No hay suficientes entradas ${tipo} disponibles. Saltando compra.';
        RETURN;
    END IF;

    -- Insertar la compra
    INSERT INTO purchases (
        id, event_id, nombre_comprador, email, telefono,
        cantidad_entradas, tipo_entrada, precio_total,
        fecha_compra, estado, codigo_confirmacion
    ) VALUES (
        '${purchase_id}',
        '${EVENT_ID}',
        '${nombre}',
        '${email}',
        '${telefono}',
        ${cantidad},
        '${tipo}',
        ${precio_total}.00,
        CURRENT_TIMESTAMP,
        'CONFIRMADA',
        '${conf_id}'
    );

    -- Marcar tickets como no disponibles y crear relación
    FOREACH v_ticket IN ARRAY v_tickets LOOP
        UPDATE tickets SET disponible = FALSE WHERE id = v_ticket;
        INSERT INTO purchase_tickets (purchase_id, ticket_id)
        VALUES ('${purchase_id}', v_ticket);
    END LOOP;

    -- Actualizar contador del evento
    UPDATE events
    SET entradas_vendidas = (
        SELECT COUNT(*) FROM tickets
        WHERE event_id = '${EVENT_ID}' AND disponible = FALSE
    )
    WHERE id = '${EVENT_ID}';

END;
\$\$;
SQL
}

# -----------------------------------------------------------------------------
# Bucle principal
# -----------------------------------------------------------------------------
compra_seq=1

while true; do
    # Comprobar entradas disponibles
    libre=$(disponibles)

    if [ "${libre}" -eq 0 ]; then
        echo ""
        echo "========================================================================"
        echo " ✓ SOLD OUT — No quedan entradas disponibles para ${EVENT_ID}"
        ${PSQL} -c "
            SELECT entradas_vendidas || ' / ' || capacidad_total AS progreso
            FROM events WHERE id = '${EVENT_ID}';"
        echo "========================================================================"
        exit 0
    fi

    # Seleccionar comprador aleatorio del pool
    idx_comp=$(shuf -i 0-$(( NUM_COMPRADORES - 1 )) -n 1)
    nombre="${NOMBRES[$idx_comp]}"

    # Cantidad aleatoria de entradas (1-4), sin superar las disponibles
    max_compra=$(( MAX_TICKETS < libre ? MAX_TICKETS : libre ))
    if [ "${max_compra}" -lt "${MIN_TICKETS}" ]; then
        max_compra=${MIN_TICKETS}
    fi
    cantidad=$(shuf -i "${MIN_TICKETS}-${max_compra}" -n 1)

    # Tipo aleatorio: 70% GENERAL, 30% VIP
    rand_tipo=$(shuf -i 1-10 -n 1)
    if [ "${rand_tipo}" -le 7 ]; then
        tipo="GENERAL"
    else
        tipo="VIP"
    fi

    # Mostrar información de la compra
    vendidas=$(${PSQL} -tAc "SELECT entradas_vendidas FROM events WHERE id='${EVENT_ID}';")
    capacidad=$(${PSQL} -tAc "SELECT capacidad_total FROM events WHERE id='${EVENT_ID}';")
    echo "[$(date '+%H:%M:%S')] Compra #${compra_seq} | ${nombre} | ${cantidad}x ${tipo} | Vendidas: ${vendidas}/${capacidad} | Disponibles: ${libre}"

    # Realizar la compra
    realizar_compra "${compra_seq}" "${nombre}" "${cantidad}" "${tipo}"

    compra_seq=$(( compra_seq + 1 ))

    # Comprobar de nuevo si ya se agotaron tras la compra
    libre=$(disponibles)
    if [ "${libre}" -eq 0 ]; then
        echo ""
        echo "========================================================================"
        echo " ✓ SOLD OUT — Última entrada vendida en la compra #$(( compra_seq - 1 ))"
        ${PSQL} -c "
            SELECT entradas_vendidas || ' / ' || capacidad_total AS progreso
            FROM events WHERE id = '${EVENT_ID}';"
        echo "========================================================================"
        exit 0
    fi

    # Espera aleatoria entre MIN_WAIT y MAX_WAIT segundos
    wait_sec=$(shuf -i "${MIN_WAIT}-${MAX_WAIT}" -n 1)
    wait_min=$(echo "scale=1; ${wait_sec}/60" | bc)
    echo "   → Próxima compra en ${wait_sec}s (${wait_min} min)..."
    sleep "${wait_sec}"
done
