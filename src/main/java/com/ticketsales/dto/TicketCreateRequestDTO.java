package com.ticketsales.dto;

import java.io.Serializable;

/**
 * DTO para solicitudes de creación de tickets en lote
 *
 * Campos:
 *   eventId   — ID del evento (por defecto "F1-2026-ESP")
 *   tipo      — "GENERAL" o "VIP"
 *   asiento   — código de asiento (e.g. "V3-A01")
 *   seccion   — sección del asiento (e.g. "V3")
 */
public class TicketCreateRequestDTO implements Serializable {
    private static final long serialVersionUID = 1L;

    private String eventId;
    private String tipo;
    private String asiento;
    private String seccion;

    public TicketCreateRequestDTO() {
    }

    public String getEventId() {
        return eventId;
    }

    public void setEventId(String eventId) {
        this.eventId = eventId;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public String getAsiento() {
        return asiento;
    }

    public void setAsiento(String asiento) {
        this.asiento = asiento;
    }

    public String getSeccion() {
        return seccion;
    }

    public void setSeccion(String seccion) {
        this.seccion = seccion;
    }
}

// Made with Bob
