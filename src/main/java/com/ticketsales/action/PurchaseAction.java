package com.ticketsales.action;

import com.opensymphony.xwork2.ActionSupport;
import com.ticketsales.model.Event;
import com.ticketsales.model.Purchase;
import com.ticketsales.model.Ticket;
import com.ticketsales.model.Ticket.TipoEntrada;
import com.ticketsales.repository.EventRepository;
import com.ticketsales.repository.PurchaseRepository;
import com.ticketsales.repository.TicketRepository;
import org.apache.struts2.interceptor.SessionAware;

import java.util.List;
import java.util.Map;

public class PurchaseAction extends ActionSupport implements SessionAware {
    private static final long serialVersionUID = 1L;
    
    private Map<String, Object> session;
    private PurchaseRepository purchaseRepo = PurchaseRepository.getInstance();
    private TicketRepository ticketRepo = TicketRepository.getInstance();
    private EventRepository eventRepo = EventRepository.getInstance();
    
    // Propiedades del formulario
    private String nombreComprador;
    private String email;
    private String telefono;
    private int cantidadEntradas;
    private String tipoEntrada;
    
    // Propiedades para la vista
    private Purchase purchase;
    private Event event;
    private String errorMessage;
    private List<Purchase> recentPurchases;
    
    public String showForm() {
        event = eventRepo.getEvent();
        
        // Verificar si hay entradas disponibles
        if (eventRepo.isSoldOut()) {
            errorMessage = "Lo sentimos, el evento está agotado.";
            return ERROR;
        }
        
        return SUCCESS;
    }
    
    public String processPurchase() {
        // Validaciones
        if (!validatePurchaseData()) {
            event = eventRepo.getEvent();
            return INPUT;
        }
        
        try {
            TipoEntrada tipo = TipoEntrada.valueOf(tipoEntrada);
            
            // Verificar disponibilidad
            if (!eventRepo.checkCapacity(cantidadEntradas)) {
                errorMessage = "No hay suficientes entradas disponibles. Solo quedan " + 
                              eventRepo.getRemainingCapacity() + " entradas.";
                event = eventRepo.getEvent();
                return INPUT;
            }
            
            // Verificar disponibilidad por tipo
            long availableByType = ticketRepo.countAvailableByType(tipo);
            if (availableByType < cantidadEntradas) {
                errorMessage = "No hay suficientes entradas " + tipo.getDescripcion() + 
                              " disponibles. Solo quedan " + availableByType + " entradas de este tipo.";
                event = eventRepo.getEvent();
                return INPUT;
            }
            
            // Reservar tickets
            List<Ticket> reservedTickets = ticketRepo.reserveTickets(tipo, cantidadEntradas);
            if (reservedTickets == null || reservedTickets.isEmpty()) {
                errorMessage = "Error al reservar las entradas. Por favor, inténtelo de nuevo.";
                event = eventRepo.getEvent();
                return INPUT;
            }
            
            // Crear la compra
            purchase = new Purchase();
            purchase.setEventId(eventRepo.getEvent().getId());
            purchase.setNombreComprador(nombreComprador);
            purchase.setEmail(email);
            purchase.setTelefono(telefono);
            purchase.setCantidadEntradas(cantidadEntradas);
            purchase.setTipoEntrada(tipo);
            
            // Asignar asientos
            for (Ticket ticket : reservedTickets) {
                purchase.agregarAsiento(ticket.getAsiento());
            }
            
            // Guardar la compra
            purchase = purchaseRepo.createPurchase(purchase);
            purchase.confirmar();
            purchaseRepo.updatePurchase(purchase);
            
            // Actualizar el contador de entradas vendidas
            eventRepo.updateSoldTickets(cantidadEntradas);
            
            // Guardar en sesión para la confirmación
            session.put("lastPurchase", purchase);
            
            return SUCCESS;
            
        } catch (IllegalArgumentException e) {
            errorMessage = "Tipo de entrada no válido.";
            event = eventRepo.getEvent();
            return INPUT;
        } catch (Exception e) {
            errorMessage = "Error al procesar la compra: " + e.getMessage();
            event = eventRepo.getEvent();
            return ERROR;
        }
    }
    
    public String confirmation() {
        purchase = (Purchase) session.get("lastPurchase");
        
        if (purchase == null) {
            errorMessage = "No se encontró información de la compra.";
            return ERROR;
        }
        
        event = eventRepo.getEvent();
        return SUCCESS;
    }
    
    public String list() {
        recentPurchases = purchaseRepo.getRecentPurchases(50);
        return SUCCESS;
    }
    
    private boolean validatePurchaseData() {
        boolean valid = true;
        
        if (nombreComprador == null || nombreComprador.trim().isEmpty()) {
            addFieldError("nombreComprador", "El nombre es obligatorio");
            valid = false;
        }
        
        if (email == null || email.trim().isEmpty()) {
            addFieldError("email", "El email es obligatorio");
            valid = false;
        } else if (!email.matches("^[A-Za-z0-9+_.-]+@(.+)$")) {
            addFieldError("email", "El email no es válido");
            valid = false;
        }
        
        if (telefono == null || telefono.trim().isEmpty()) {
            addFieldError("telefono", "El teléfono es obligatorio");
            valid = false;
        }
        
        if (cantidadEntradas <= 0) {
            addFieldError("cantidadEntradas", "Debe seleccionar al menos 1 entrada");
            valid = false;
        } else if (cantidadEntradas > 10) {
            addFieldError("cantidadEntradas", "No puede comprar más de 10 entradas por transacción");
            valid = false;
        }
        
        if (tipoEntrada == null || tipoEntrada.trim().isEmpty()) {
            addFieldError("tipoEntrada", "Debe seleccionar un tipo de entrada");
            valid = false;
        }
        
        return valid;
    }
    
    // Getters y Setters
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
    
    public Purchase getPurchase() {
        return purchase;
    }
    
    public void setPurchase(Purchase purchase) {
        this.purchase = purchase;
    }
    
    public Event getEvent() {
        return event;
    }
    
    public void setEvent(Event event) {
        this.event = event;
    }
    
    public String getErrorMessage() {
        return errorMessage;
    }
    
    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }
    
    public List<Purchase> getRecentPurchases() {
        return recentPurchases;
    }
    
    public void setRecentPurchases(List<Purchase> recentPurchases) {
        this.recentPurchases = recentPurchases;
    }
    
    @Override
    public void setSession(Map<String, Object> session) {
        this.session = session;
    }
}

// Made with Bob