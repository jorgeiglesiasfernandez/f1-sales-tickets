package com.ticketsales.dto;

import java.io.Serializable;

/**
 * DTO para solicitudes de compra de entradas
 */
public class PurchaseRequestDTO implements Serializable {
    private static final long serialVersionUID = 1L;
    
    private String eventId;
    private String nombreComprador;
    private String email;
    private String telefono;
    private int cantidadEntradas;
    private String tipoEntrada; // "GENERAL" o "VIP"
    
    public PurchaseRequestDTO() {
    }
    
    // Getters and Setters
    public String getEventId() {
        return eventId;
    }
    
    public void setEventId(String eventId) {
        this.eventId = eventId;
    }
    
    public String getNombreComprador() {
        return nombreComprador;
    }
    
    public void setNombreComprador(String nombreComprador) {
        this.nombreComprador = nombreComprador;
    }
    
    public String getEmail() {
        return email;
    }
    
    public void setEmail(String email) {
        this.email = email;
    }
    
    public String getTelefono() {
        return telefono;
    }
    
    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }
    
    public int getCantidadEntradas() {
        return cantidadEntradas;
    }
    
    public void setCantidadEntradas(int cantidadEntradas) {
        this.cantidadEntradas = cantidadEntradas;
    }
    
    public String getTipoEntrada() {
        return tipoEntrada;
    }
    
    public void setTipoEntrada(String tipoEntrada) {
        this.tipoEntrada = tipoEntrada;
    }
}

// Made with Bob
