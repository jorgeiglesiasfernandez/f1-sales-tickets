package com.ticketsales.dto;

import com.ticketsales.model.Ticket;
import java.io.Serializable;
import java.math.BigDecimal;

/**
 * DTO para información de tickets
 */
public class TicketDTO implements Serializable {
    private static final long serialVersionUID = 1L;
    
    private String id;
    private String eventId;
    private String tipo;
    private BigDecimal precio;
    private String asiento;
    private String seccion;
    private boolean disponible;
    private String descripcionCompleta;
    
    public TicketDTO() {
    }
    
    public TicketDTO(Ticket ticket) {
        this.id = ticket.getId();
        this.eventId = ticket.getEventId();
        this.tipo = ticket.getTipo() != null ? ticket.getTipo().name() : null;
        this.precio = ticket.getPrecio();
        this.asiento = ticket.getAsiento();
        this.seccion = ticket.getSeccion();
        this.disponible = ticket.isDisponible();
        this.descripcionCompleta = ticket.getDescripcionCompleta();
    }
    
    // Getters and Setters
    public String getId() {
        return id;
    }
    
    public void setId(String id) {
        this.id = id;
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
    
    public BigDecimal getPrecio() {
        return precio;
    }
    
    public void setPrecio(BigDecimal precio) {
        this.precio = precio;
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
    
    public boolean isDisponible() {
        return disponible;
    }
    
    public void setDisponible(boolean disponible) {
        this.disponible = disponible;
    }
    
    public String getDescripcionCompleta() {
        return descripcionCompleta;
    }
    
    public void setDescripcionCompleta(String descripcionCompleta) {
        this.descripcionCompleta = descripcionCompleta;
    }
}

// Made with Bob
