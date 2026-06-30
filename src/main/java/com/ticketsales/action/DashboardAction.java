package com.ticketsales.action;

import com.opensymphony.xwork2.ActionSupport;
import com.ticketsales.model.Event;
import com.ticketsales.model.Purchase;
import com.ticketsales.model.Ticket.TipoEntrada;
import com.ticketsales.repository.EventRepository;
import com.ticketsales.repository.PurchaseRepository;
import com.ticketsales.repository.TicketRepository;
import org.apache.struts2.interceptor.SessionAware;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public class DashboardAction extends ActionSupport implements SessionAware {
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
    private List<Purchase> comprasRecientes;
    private Map<String, Integer> ventasPorTipo;
    private double promedioEntradasPorCompra;
    
    public String execute() {
        // Información del evento
        event = eventRepo.getEvent();
        entradasDisponibles = eventRepo.getRemainingCapacity();
        entradasVendidas = eventRepo.getTotalSold();
        porcentajeVendido = eventRepo.getPercentageSold();
        
        // Disponibilidad por tipo
        Map<TipoEntrada, Long> availability = ticketRepo.getAvailabilityByType();
        generalDisponibles = availability.getOrDefault(TipoEntrada.GENERAL, 0L);
        vipDisponibles = availability.getOrDefault(TipoEntrada.VIP, 0L);
        
        // Estadísticas de compras
        totalCompras = purchaseRepo.getTotalPurchases();
        ingresosTotales = purchaseRepo.getTotalRevenue();
        comprasRecientes = purchaseRepo.getRecentPurchases(10);
        ventasPorTipo = purchaseRepo.getSalesByType();
        promedioEntradasPorCompra = purchaseRepo.getAverageTicketsPerPurchase();
        
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
    
    public List<Purchase> getComprasRecientes() {
        return comprasRecientes;
    }
    
    public void setComprasRecientes(List<Purchase> comprasRecientes) {
        this.comprasRecientes = comprasRecientes;
    }
    
    public Map<String, Integer> getVentasPorTipo() {
        return ventasPorTipo;
    }
    
    public void setVentasPorTipo(Map<String, Integer> ventasPorTipo) {
        this.ventasPorTipo = ventasPorTipo;
    }
    
    public double getPromedioEntradasPorCompra() {
        return promedioEntradasPorCompra;
    }
    
    public void setPromedioEntradasPorCompra(double promedioEntradasPorCompra) {
        this.promedioEntradasPorCompra = promedioEntradasPorCompra;
    }
    
    @Override
    public void setSession(Map<String, Object> session) {
        this.session = session;
    }
}

// Made with Bob