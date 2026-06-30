package com.ticketsales.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

public class Purchase implements Serializable {
    private static final long serialVersionUID = 1L;
    
    private String id;
    private String eventId;
    private String nombreComprador;
    private String email;
    private String telefono;
    private int cantidadEntradas;
    private Ticket.TipoEntrada tipoEntrada;
    private List<String> asientosAsignados;
    private Date fechaCompra;
    private BigDecimal precioTotal;
    private String estado; // CONFIRMADA, CANCELADA, PENDIENTE
    private String codigoConfirmacion;
    
    public Purchase() {
        this.asientosAsignados = new ArrayList<>();
        this.fechaCompra = new Date();
        this.estado = "PENDIENTE";
    }
    
    public Purchase(String id, String eventId, String nombreComprador, String email, String telefono,
                   int cantidadEntradas, Ticket.TipoEntrada tipoEntrada) {
        this.id = id;
        this.eventId = eventId;
        this.nombreComprador = nombreComprador;
        this.email = email;
        this.telefono = telefono;
        this.cantidadEntradas = cantidadEntradas;
        this.tipoEntrada = tipoEntrada;
        this.asientosAsignados = new ArrayList<>();
        this.fechaCompra = new Date();
        this.estado = "PENDIENTE";
        calcularPrecioTotal();
    }
    
    // Métodos de negocio
    public void calcularPrecioTotal() {
        if (tipoEntrada != null) {
            this.precioTotal = tipoEntrada.getPrecio().multiply(new BigDecimal(cantidadEntradas));
        }
    }
    
    public void agregarAsiento(String asiento) {
        if (asientosAsignados == null) {
            asientosAsignados = new ArrayList<>();
        }
        asientosAsignados.add(asiento);
    }
    
    public void confirmar() {
        this.estado = "CONFIRMADA";
        this.codigoConfirmacion = generarCodigoConfirmacion();
    }
    
    public void cancelar() {
        this.estado = "CANCELADA";
    }
    
    private String generarCodigoConfirmacion() {
        return "F1-" + System.currentTimeMillis() + "-" + id.substring(0, Math.min(4, id.length())).toUpperCase();
    }
    
    public String getAsientosAsignadosTexto() {
        if (asientosAsignados == null || asientosAsignados.isEmpty()) {
            return "Sin asignar";
        }
        return String.join(", ", asientosAsignados);
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
        calcularPrecioTotal();
    }
    
    public Ticket.TipoEntrada getTipoEntrada() {
        return tipoEntrada;
    }
    
    public void setTipoEntrada(Ticket.TipoEntrada tipoEntrada) {
        this.tipoEntrada = tipoEntrada;
        calcularPrecioTotal();
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