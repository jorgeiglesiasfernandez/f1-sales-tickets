package com.ticketsales.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.ticketsales.model.Event;
import java.io.Serializable;
import java.util.Date;

/**
 * DTO para información de eventos
 */
public class EventDTO implements Serializable {
    private static final long serialVersionUID = 1L;
    
    private String id;
    private String nombre;
    
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss", timezone = "Europe/Madrid")
    private Date fecha;
    
    private String circuito;
    private String ubicacion;
    private String descripcion;
    private int capacidadTotal;
    private int entradasVendidas;
    private int entradasDisponibles;
    private double porcentajeVendido;
    private boolean agotado;
    
    public EventDTO() {
    }
    
    public EventDTO(Event event) {
        this.id = event.getId();
        this.nombre = event.getNombre();
        this.fecha = event.getFecha();
        this.circuito = event.getCircuito();
        this.ubicacion = event.getUbicacion();
        this.descripcion = event.getDescripcion();
        this.capacidadTotal = event.getCapacidadTotal();
        this.entradasVendidas = event.getEntradasVendidas();
        this.entradasDisponibles = event.getEntradasDisponibles();
        this.porcentajeVendido = event.getPorcentajeVendido();
        this.agotado = event.getEntradasDisponibles() == 0;
    }
    
    // Getters and Setters
    public String getId() {
        return id;
    }
    
    public void setId(String id) {
        this.id = id;
    }
    
    public String getNombre() {
        return nombre;
    }
    
    public void setNombre(String nombre) {
        this.nombre = nombre;
    }
    
    public Date getFecha() {
        return fecha;
    }
    
    public void setFecha(Date fecha) {
        this.fecha = fecha;
    }
    
    public String getCircuito() {
        return circuito;
    }
    
    public void setCircuito(String circuito) {
        this.circuito = circuito;
    }
    
    public String getUbicacion() {
        return ubicacion;
    }
    
    public void setUbicacion(String ubicacion) {
        this.ubicacion = ubicacion;
    }
    
    public String getDescripcion() {
        return descripcion;
    }
    
    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }
    
    public int getCapacidadTotal() {
        return capacidadTotal;
    }
    
    public void setCapacidadTotal(int capacidadTotal) {
        this.capacidadTotal = capacidadTotal;
    }
    
    public int getEntradasVendidas() {
        return entradasVendidas;
    }
    
    public void setEntradasVendidas(int entradasVendidas) {
        this.entradasVendidas = entradasVendidas;
    }
    
    public int getEntradasDisponibles() {
        return entradasDisponibles;
    }
    
    public void setEntradasDisponibles(int entradasDisponibles) {
        this.entradasDisponibles = entradasDisponibles;
    }
    
    public double getPorcentajeVendido() {
        return porcentajeVendido;
    }
    
    public void setPorcentajeVendido(double porcentajeVendido) {
        this.porcentajeVendido = porcentajeVendido;
    }
    
    public boolean isAgotado() {
        return agotado;
    }
    
    public void setAgotado(boolean agotado) {
        this.agotado = agotado;
    }
}

// Made with Bob
