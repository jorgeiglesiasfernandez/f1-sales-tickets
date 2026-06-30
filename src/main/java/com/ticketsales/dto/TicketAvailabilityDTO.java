package com.ticketsales.dto;

import java.io.Serializable;
import java.math.BigDecimal;

/**
 * DTO para información de disponibilidad de tickets por tipo
 */
public class TicketAvailabilityDTO implements Serializable {
    private static final long serialVersionUID = 1L;
    
    private String tipo;
    private long disponibles;
    private BigDecimal precio;
    
    public TicketAvailabilityDTO() {
    }
    
    public TicketAvailabilityDTO(String tipo, long disponibles, BigDecimal precio) {
        this.tipo = tipo;
        this.disponibles = disponibles;
        this.precio = precio;
    }
    
    // Getters and Setters
    public String getTipo() {
        return tipo;
    }
    
    public void setTipo(String tipo) {
        this.tipo = tipo;
    }
    
    public long getDisponibles() {
        return disponibles;
    }
    
    public void setDisponibles(long disponibles) {
        this.disponibles = disponibles;
    }
    
    public BigDecimal getPrecio() {
        return precio;
    }
    
    public void setPrecio(BigDecimal precio) {
        this.precio = precio;
    }
}

// Made with Bob
