package com.ticketsales.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.ticketsales.model.Purchase;
import java.io.Serializable;
import java.math.BigDecimal;
import java.util.Date;
import java.util.List;

/**
 * DTO para información de compras
 */
public class PurchaseDTO implements Serializable {
    private static final long serialVersionUID = 1L;
    
    private String id;
    private String eventId;
    private String nombreComprador;
    private String email;
    private String telefono;
    private int cantidadEntradas;
    private String tipoEntrada;
    private List<String> asientosAsignados;
    
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss", timezone = "Europe/Madrid")
    private Date fechaCompra;
    
    private BigDecimal precioTotal;
    private String estado;
    private String codigoConfirmacion;
    
    public PurchaseDTO() {
    }
    
    public PurchaseDTO(Purchase purchase) {
        this.id = purchase.getId();
        this.eventId = purchase.getEventId();
        this.nombreComprador = purchase.getNombreComprador();
        this.email = purchase.getEmail();
        this.telefono = purchase.getTelefono();
        this.cantidadEntradas = purchase.getCantidadEntradas();
        this.tipoEntrada = purchase.getTipoEntrada() != null ? purchase.getTipoEntrada().name() : null;
        this.asientosAsignados = purchase.getAsientosAsignados();
        this.fechaCompra = purchase.getFechaCompra();
        this.precioTotal = purchase.getPrecioTotal();
        this.estado = purchase.getEstado();
        this.codigoConfirmacion = purchase.getCodigoConfirmacion();
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
    
    public List<String> getAsientosAsignados() {
        return asientosAsignados;
    }
    
    public void setAsientosAsignados(List<String> asientosAsignados) {
        this.asientosAsignados = asientosAsignados;
    }
    
    public Date getFechaCompra() {
        return fechaCompra;
    }
    
    public void setFechaCompra(Date fechaCompra) {
        this.fechaCompra = fechaCompra;
    }
    
    public BigDecimal getPrecioTotal() {
        return precioTotal;
    }
    
    public void setPrecioTotal(BigDecimal precioTotal) {
        this.precioTotal = precioTotal;
    }
    
    public String getEstado() {
        return estado;
    }
    
    public void setEstado(String estado) {
        this.estado = estado;
    }
    
    public String getCodigoConfirmacion() {
        return codigoConfirmacion;
    }
    
    public void setCodigoConfirmacion(String codigoConfirmacion) {
        this.codigoConfirmacion = codigoConfirmacion;
    }
}

// Made with Bob
