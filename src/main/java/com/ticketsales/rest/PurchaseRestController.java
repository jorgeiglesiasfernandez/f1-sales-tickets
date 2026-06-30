package com.ticketsales.rest;

import com.ticketsales.dto.ApiResponse;
import com.ticketsales.dto.PurchaseDTO;
import com.ticketsales.dto.PurchaseRequestDTO;
import com.ticketsales.model.Purchase;
import com.ticketsales.model.Ticket;
import com.ticketsales.model.Ticket.TipoEntrada;
import com.ticketsales.repository.EventRepository;
import com.ticketsales.repository.PurchaseRepository;
import com.ticketsales.repository.TicketRepository;

import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Controlador REST para operaciones de compra
 * Base path: /api/purchases
 */
@Path("/purchases")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class PurchaseRestController {
    
    private final PurchaseRepository purchaseRepository;
    private final TicketRepository ticketRepository;
    private final EventRepository eventRepository;
    
    public PurchaseRestController() {
        this.purchaseRepository = PurchaseRepository.getInstance();
        this.ticketRepository = TicketRepository.getInstance();
        this.eventRepository = EventRepository.getInstance();
    }
    
    /**
     * POST /api/purchases
     * Crea una nueva compra de entradas
     */
    @POST
    public Response createPurchase(PurchaseRequestDTO request) {
        try {
            // Validar datos de entrada
            if (request == null) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("Datos de compra requeridos"))
                    .build();
            }
            
            if (request.getNombreComprador() == null || request.getNombreComprador().trim().isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("Nombre del comprador es requerido"))
                    .build();
            }
            
            if (request.getEmail() == null || request.getEmail().trim().isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("Email es requerido"))
                    .build();
            }
            
            if (request.getCantidadEntradas() <= 0) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("Cantidad de entradas debe ser mayor a 0"))
                    .build();
            }
            
            if (request.getCantidadEntradas() > 10) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("No se pueden comprar más de 10 entradas por transacción"))
                    .build();
            }
            
            // Validar tipo de entrada
            TipoEntrada tipoEntrada;
            try {
                tipoEntrada = TipoEntrada.valueOf(request.getTipoEntrada().toUpperCase());
            } catch (Exception e) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("Tipo de entrada inválido. Use: GENERAL o VIP"))
                    .build();
            }
            
            // Verificar disponibilidad en el evento
            if (!eventRepository.checkCapacity(request.getCantidadEntradas())) {
                return Response.status(Response.Status.CONFLICT)
                    .entity(ApiResponse.error("No hay suficientes entradas disponibles en el evento"))
                    .build();
            }
            
            // Verificar disponibilidad de tickets del tipo solicitado
            long availableTickets = ticketRepository.countAvailableByType(tipoEntrada);
            if (availableTickets < request.getCantidadEntradas()) {
                return Response.status(Response.Status.CONFLICT)
                    .entity(ApiResponse.error("No hay suficientes entradas " + tipoEntrada.name() + " disponibles. Disponibles: " + availableTickets))
                    .build();
            }
            
            // Reservar tickets
            List<Ticket> reservedTickets = ticketRepository.reserveTickets(tipoEntrada, request.getCantidadEntradas());
            if (reservedTickets == null || reservedTickets.isEmpty()) {
                return Response.status(Response.Status.CONFLICT)
                    .entity(ApiResponse.error("Error al reservar tickets"))
                    .build();
            }
            
            // Actualizar contador del evento
            if (!eventRepository.updateSoldTickets(request.getCantidadEntradas())) {
                // Revertir reserva de tickets
                ticketRepository.releaseTickets(
                    reservedTickets.stream().map(Ticket::getId).collect(Collectors.toList())
                );
                return Response.status(Response.Status.CONFLICT)
                    .entity(ApiResponse.error("Error al actualizar disponibilidad del evento"))
                    .build();
            }
            
            // Crear la compra
            Purchase purchase = new Purchase(
                null, // El ID se genera automáticamente
                request.getEventId() != null ? request.getEventId() : "F1-2026-ESP",
                request.getNombreComprador(),
                request.getEmail(),
                request.getTelefono(),
                request.getCantidadEntradas(),
                tipoEntrada
            );
            
            // Asignar asientos
            for (Ticket ticket : reservedTickets) {
                purchase.agregarAsiento(ticket.getAsiento());
            }
            
            // Confirmar la compra
            purchase.confirmar();
            
            // Guardar en el repositorio
            Purchase savedPurchase = purchaseRepository.createPurchase(purchase);
            
            PurchaseDTO purchaseDTO = new PurchaseDTO(savedPurchase);
            return Response.status(Response.Status.CREATED)
                .entity(ApiResponse.success("Compra realizada exitosamente", purchaseDTO))
                .build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al procesar la compra: " + e.getMessage()))
                .build();
        }
    }
    
    /**
     * GET /api/purchases/{id}
     * Obtiene información de una compra específica
     */
    @GET
    @Path("/{id}")
    public Response getPurchaseById(@PathParam("id") String id) {
        try {
            Purchase purchase = purchaseRepository.findById(id);
            
            if (purchase == null) {
                return Response.status(Response.Status.NOT_FOUND)
                    .entity(ApiResponse.error("Compra no encontrada con ID: " + id))
                    .build();
            }
            
            PurchaseDTO purchaseDTO = new PurchaseDTO(purchase);
            return Response.ok(ApiResponse.success(purchaseDTO)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener la compra: " + e.getMessage()))
                .build();
        }
    }
    
    /**
     * GET /api/purchases
     * Obtiene todas las compras (con filtros opcionales)
     */
    @GET
    public Response getPurchases(
            @QueryParam("email") String email,
            @QueryParam("estado") String estado,
            @QueryParam("limit") @DefaultValue("50") int limit) {
        try {
            List<Purchase> purchases;
            
            if (email != null && !email.isEmpty()) {
                purchases = purchaseRepository.findByEmail(email);
            } else if (estado != null && !estado.isEmpty()) {
                purchases = purchaseRepository.findByEstado(estado.toUpperCase());
            } else {
                purchases = purchaseRepository.getRecentPurchases(limit);
            }
            
            List<PurchaseDTO> purchaseDTOs = purchases.stream()
                .limit(limit)
                .map(PurchaseDTO::new)
                .collect(Collectors.toList());
            
            return Response.ok(ApiResponse.success(purchaseDTOs)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener compras: " + e.getMessage()))
                .build();
        }
    }
    
    /**
     * GET /api/purchases/stats
     * Obtiene estadísticas de compras
     */
    @GET
    @Path("/stats")
    public Response getPurchaseStats() {
        try {
            java.util.Map<String, Object> stats = new java.util.HashMap<>();
            stats.put("totalCompras", purchaseRepository.getTotalPurchases());
            stats.put("totalEntradasVendidas", purchaseRepository.getTotalTicketsSold());
            stats.put("ingresoTotal", purchaseRepository.getTotalRevenue());
            stats.put("ventasPorTipo", purchaseRepository.getSalesByType());
            stats.put("promedioEntradasPorCompra", purchaseRepository.getAverageTicketsPerPurchase());
            
            return Response.ok(ApiResponse.success("Estadísticas de compras", stats)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener estadísticas: " + e.getMessage()))
                .build();
        }
    }
}

// Made with Bob
