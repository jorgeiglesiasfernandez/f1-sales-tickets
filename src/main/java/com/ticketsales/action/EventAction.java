package com.ticketsales.action;

import com.opensymphony.xwork2.ActionSupport;
import com.ticketsales.model.Event;
import com.ticketsales.model.Ticket.TipoEntrada;
import com.ticketsales.repository.EventRepository;
import com.ticketsales.repository.PurchaseRepository;
import com.ticketsales.repository.TicketRepository;
import org.apache.struts2.interceptor.SessionAware;

import java.math.BigDecimal;
import java.util.Map;

public class EventAction extends ActionSupport implements SessionAware {
    private static final long serialVersionUID = 1L;
    
    private Map<String, Object> session;
    private EventRepository eventRepo = EventRepository.getInstance();
    private TicketRepository ticketRepo = TicketRepository.getInstance();
    private PurchaseRepository purchaseRepo = PurchaseRepository.getInstance();
    
    // Propiedades para la vista
    private Event event;
    private int entradasDisponibles;
    private int entradasVendidas;
    private double porcentajeVendido;
    private long generalDisponibles;
    private long vipDisponibles;
    private int totalCompras;
    private BigDecimal ingresosTotales;
    
    public String showInfo() {
        event = eventRepo.getEvent();
        entradasDisponibles = eventRepo.getRemainingCapacity();
        entradasVendidas = eventRepo.getTotalSold();
        porcentajeVendido = eventRepo.getPercentageSold();
        
        Map<TipoEntrada, Long> availability = ticketRepo.getAvailabilityByType();
        generalDisponibles = availability.getOrDefault(TipoEntrada.GENERAL, 0L);
        vipDisponibles = availability.getOrDefault(TipoEntrada.VIP, 0L);
        
        return SUCCESS;
    }
    
    public String getStatistics() {
        event = eventRepo.getEvent();
        entradasDisponibles = eventRepo.getRemainingCapacity();
        entradasVendidas = eventRepo.getTotalSold();
        porcentajeVendido = eventRepo.getPercentageSold();
        
        Map<TipoEntrada, Long> availability = ticketRepo.getAvailabilityByType();
        generalDisponibles = availability.getOrDefault(TipoEntrada.GENERAL, 0L);
        vipDisponibles = availability.getOrDefault(TipoEntrada.VIP, 0L);
        
        totalCompras = purchaseRepo.getTotalPurchases();
        ingresosTotales = purchaseRepo.getTotalRevenue();
        
        return SUCCESS;
    }
    
    // Getters y Setters
    public Event getEvent() {
        return event;
    }
    
    public void setEvent(Event event) {
        this.event = event;
    }
    
    public int getEntradasDisponibles() {
        return entradasDisponibles;
    }
    
    public void setEntradasDisponibles(int entradasDisponibles) {
        this.entradasDisponibles = entradasDisponibles;
    }
    
    public int getEntradasVendidas() {
        return entradasVendidas;
    }
    
    public void setEntradasVendidas(int entradasVendidas) {
        this.entradasVendidas = entradasVendidas;
    }
    
    public double getPorcentajeVendido() {
        return porcentajeVendido;
    }
    
    public void setPorcentajeVendido(double porcentajeVendido) {
        this.porcentajeVendido = porcentajeVendido;
    }
    
    public long getGeneralDisponibles() {
        return generalDisponibles;
    }
    
    public void setGeneralDisponibles(long generalDisponibles) {
        this.generalDisponibles = generalDisponibles;
    }
    
    public long getVipDisponibles() {
        return vipDisponibles;
    }
    
    public void setVipDisponibles(long vipDisponibles) {
        this.vipDisponibles = vipDisponibles;
    }
    
    public int getTotalCompras() {
        return totalCompras;
    }
    
    public void setTotalCompras(int totalCompras) {
        this.totalCompras = totalCompras;
    }
    
    public BigDecimal getIngresosTotales() {
        return ingresosTotales;
    }
    
    public void setIngresosTotales(BigDecimal ingresosTotales) {
        this.ingresosTotales = ingresosTotales;
    }
    
    @Override
    public void setSession(Map<String, Object> session) {
        this.session = session;
    }
}

// Made with Bob