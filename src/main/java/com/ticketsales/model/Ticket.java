package com.ticketsales.model;

import java.io.Serializable;
import java.math.BigDecimal;

public class Ticket implements Serializable {
    private static final long serialVersionUID = 1L;
    
    public enum TipoEntrada {
        GENERAL("General", new BigDecimal("150.00")),
        VIP("VIP", new BigDecimal("450.00"));
        
        private final String descripcion;
        private final BigDecimal precio;
        
        TipoEntrada(String descripcion, BigDecimal precio) {
            this.descripcion = descripcion;
            this.precio = precio;
        }
        
        public String getDescripcion() {
            return descripcion;
        }
        
        public BigDecimal getPrecio() {
            return precio;
        }
    }
    
    private String id;
    private String eventId;
    private TipoEntrada tipo;
    private BigDecimal precio;
    private String asiento;
    private boolean disponible;
    private String seccion;
    
    public Ticket() {
        this.disponible = true;
    }
    
    public Ticket(String id, String eventId, TipoEntrada tipo, String asiento, String seccion) {
        this.id = id;
        this.eventId = eventId;
        this.tipo = tipo;
        this.precio = tipo.getPrecio();
        this.asiento = asiento;
        this.seccion = seccion;
        this.disponible = true;
    }
    
    // Métodos de negocio
    public void reservar() {
        this.disponible = false;
    }
    
    public void liberar() {
        this.disponible = true;
    }
    
    public String getDescripcionCompleta() {
        return tipo.getDescripcion() + " - Sección " + seccion + " - Asiento " + asiento;
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
    
    public TipoEntrada getTipo() {
        return tipo;
    }
    
    public void setTipo(TipoEntrada tipo) {
        this.tipo = tipo;
        if (tipo != null) {
            this.precio = tipo.getPrecio();
        }
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
    
    public boolean isDisponible() {
        return disponible;
    }
    
    public void setDisponible(boolean disponible) {
        this.disponible = disponible;
    }
    
    public String getSeccion() {
        return seccion;
    }
    
    public void setSeccion(String seccion) {
        this.seccion = seccion;
    }
}

// Made with Bob