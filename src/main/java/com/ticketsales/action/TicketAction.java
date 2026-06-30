package com.ticketsales.action;

import com.opensymphony.xwork2.ActionSupport;
import com.ticketsales.model.Event;
import com.ticketsales.model.Ticket;
import com.ticketsales.model.Ticket.TipoEntrada;
import com.ticketsales.repository.EventRepository;
import com.ticketsales.repository.TicketRepository;
import org.apache.struts2.interceptor.SessionAware;

import java.util.List;
import java.util.Map;

public class TicketAction extends ActionSupport implements SessionAware {
    private static final long serialVersionUID = 1L;
    
    private Map<String, Object> session;
    private TicketRepository ticketRepo = TicketRepository.getInstance();
    private EventRepository eventRepo = EventRepository.getInstance();
    
    // Propiedades para la vista
    private List<Ticket> availableTickets;
    private Event event;
    private long generalAvailable;
    private long vipAvailable;
    private int totalAvailable;
    private String tipoFiltro;
    
    public String list() {
        event = eventRepo.getEvent();
        availableTickets = ticketRepo.getAvailableTickets();
        
        // Filtrar por tipo si se especifica
        if (tipoFiltro != null && !tipoFiltro.isEmpty()) {
            try {
                TipoEntrada tipo = TipoEntrada.valueOf(tipoFiltro);
                availableTickets = ticketRepo.getAvailableTicketsByType(tipo);
            } catch (IllegalArgumentException e) {
                // Si el tipo no es válido, mostrar todos
            }
        }
        
        // Obtener estadísticas
        Map<TipoEntrada, Long> availability = ticketRepo.getAvailabilityByType();
        generalAvailable = availability.getOrDefault(TipoEntrada.GENERAL, 0L);
        vipAvailable = availability.getOrDefault(TipoEntrada.VIP, 0L);
        totalAvailable = ticketRepo.getRemainingCapacity();
        
        return SUCCESS;
    }
    
    public String checkAvailability() {
        event = eventRepo.getEvent();
        Map<TipoEntrada, Long> availability = ticketRepo.getAvailabilityByType();
        generalAvailable = availability.getOrDefault(TipoEntrada.GENERAL, 0L);
        vipAvailable = availability.getOrDefault(TipoEntrada.VIP, 0L);
        totalAvailable = ticketRepo.getRemainingCapacity();
        
        return SUCCESS;
    }
    
    // Getters y Setters
    public List<Ticket> getAvailableTickets() {
        return availableTickets;
    }
    
    public void setAvailableTickets(List<Ticket> availableTickets) {
        this.availableTickets = availableTickets;
    }
    
    public Event getEvent() {
        return event;
    }
    
    public void setEvent(Event event) {
        this.event = event;
    }
    
    public long getGeneralAvailable() {
        return generalAvailable;
    }
    
    public void setGeneralAvailable(long generalAvailable) {
        this.generalAvailable = generalAvailable;
    }
    
    public long getVipAvailable() {
        return vipAvailable;
    }
    
    public void setVipAvailable(long vipAvailable) {
        this.vipAvailable = vipAvailable;
    }
    
    public int getTotalAvailable() {
        return totalAvailable;
    }
    
    public void setTotalAvailable(int totalAvailable) {
        this.totalAvailable = totalAvailable;
    }
    
    public String getTipoFiltro() {
        return tipoFiltro;
    }
    
    public void setTipoFiltro(String tipoFiltro) {
        this.tipoFiltro = tipoFiltro;
    }
    
    @Override
    public void setSession(Map<String, Object> session) {
        this.session = session;
    }
}

// Made with Bob