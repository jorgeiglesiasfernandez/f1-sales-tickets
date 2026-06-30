package com.ticketsales.model;

import java.io.Serializable;
import java.util.Date;

public class Event implements Serializable {
    private static final long serialVersionUID = 1L;
    
    public static final int MAX_CAPACITY = 1000;
    
    private String id;
    private String nombre;
    private Date fecha;
    private String circuito;
    private String ubicacion;
    private int capacidadTotal;
    private int entradasVendidas;
    private String descripcion;
    
    public Event() {
        this.capacidadTotal = MAX_CAPACITY;
        this.entradasVendidas = 0;
    }
    
    public Event(String id, String nombre, Date fecha, String circuito, String ubicacion, String descripcion) {
        this.id = id;
        this.nombre = nombre;
        this.fecha = fecha;
        this.circuito = circuito;
        this.ubicacion = ubicacion;
        this.capacidadTotal = MAX_CAPACITY;
        this.entradasVendidas = 0;
        this.descripcion = descripcion;
    }
    
    // Métodos de negocio
    public int getEntradasDisponibles() {
        return capacidadTotal - entradasVendidas;
    }
    
    public boolean hayDisponibilidad(int cantidad) {
        return (entradasVendidas + cantidad) <= capacidadTotal;
    }
    
    public boolean venderEntradas(int cantidad) {
        if (hayDisponibilidad(cantidad)) {
            entradasVendidas += cantidad;
            return true;
        }
        return false;
    }
    
    public double getPorcentajeVendido() {
        return (entradasVendidas * 100.0) / capacidadTotal;
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
    
    public String getDescripcion() {
        return descripcion;
    }
    
    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }
}

// Made with Bob