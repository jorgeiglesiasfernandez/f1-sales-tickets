package com.ticketsales.rest;

import com.ticketsales.dto.ApiResponse;
import com.ticketsales.dto.TicketAvailabilityDTO;
import com.ticketsales.dto.TicketDTO;
import com.ticketsales.model.Ticket;
import com.ticketsales.model.Ticket.TipoEntrada;
import com.ticketsales.repository.TicketRepository;

import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Controlador REST para operaciones con tickets
 * Base path: /api/tickets
 */
@Path("/tickets")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TicketRestController {
    
    private final TicketRepository ticketRepository;
    
    public TicketRestController() {
        this.ticketRepository = TicketRepository.getInstance();
    }
    
    /**
     * GET /api/tickets/available
     * Obtiene todos los tickets disponibles
     */
    @GET
    @Path("/available")
    public Response getAvailableTickets(
            @QueryParam("tipo") String tipo,
            @QueryParam("limit") @DefaultValue("100") int limit) {
        try {
            List<Ticket> tickets;
            
            if (tipo != null && !tipo.isEmpty()) {
                try {
                    TipoEntrada tipoEntrada = TipoEntrada.valueOf(tipo.toUpperCase());
                    tickets = ticketRepository.getAvailableTicketsByType(tipoEntrada);
                } catch (IllegalArgumentException e) {
                    return Response.status(Response.Status.BAD_REQUEST)
                        .entity(ApiResponse.error("Tipo de entrada inválido. Use: GENERAL o VIP"))
                        .build();
                }
            } else {
                tickets = ticketRepository.getAvailableTickets();
            }
            
            // Limitar resultados
            List<TicketDTO> ticketDTOs = tickets.stream()
                .limit(limit)
                .map(TicketDTO::new)
                .collect(Collectors.toList());
            
            return Response.ok(ApiResponse.success(ticketDTOs)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener tickets: " + e.getMessage()))
                .build();
        }
    }
    
    /**
     * GET /api/tickets/availability
     * Obtiene información de disponibilidad por tipo de entrada
     */
    @GET
    @Path("/availability")
    public Response getTicketAvailability() {
        try {
            Map<TipoEntrada, Long> availability = ticketRepository.getAvailabilityByType();
            
            List<TicketAvailabilityDTO> availabilityList = new ArrayList<>();
            for (Map.Entry<TipoEntrada, Long> entry : availability.entrySet()) {
                availabilityList.add(new TicketAvailabilityDTO(
                    entry.getKey().name(),
                    entry.getValue(),
                    entry.getKey().getPrecio()
                ));
            }
            
            return Response.ok(ApiResponse.success("Disponibilidad de tickets", availabilityList)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener disponibilidad: " + e.getMessage()))
                .build();
        }
    }
    
    /**
     * GET /api/tickets/{id}
     * Obtiene información de un ticket específico
     */
    @GET
    @Path("/{id}")
    public Response getTicketById(@PathParam("id") String id) {
        try {
            Ticket ticket = ticketRepository.findById(id);
            
            if (ticket == null) {
                return Response.status(Response.Status.NOT_FOUND)
                    .entity(ApiResponse.error("Ticket no encontrado con ID: " + id))
                    .build();
            }
            
            TicketDTO ticketDTO = new TicketDTO(ticket);
            return Response.ok(ApiResponse.success(ticketDTO)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener ticket: " + e.getMessage()))
                .build();
        }
    }
    
    /**
     * GET /api/tickets/stats
     * Obtiene estadísticas de tickets
     */
    @GET
    @Path("/stats")
    public Response getTicketStats() {
        try {
            java.util.Map<String, Object> stats = new java.util.HashMap<>();
            stats.put("capacidadTotal", ticketRepository.getTotalCapacity());
            stats.put("disponibles", ticketRepository.getRemainingCapacity());
            stats.put("vendidos", ticketRepository.getSoldTickets());
            stats.put("porcentajeVendido", 
                (ticketRepository.getSoldTickets() * 100.0) / ticketRepository.getTotalCapacity());
            
            Map<TipoEntrada, Long> availabilityByType = ticketRepository.getAvailabilityByType();
            stats.put("disponiblesPorTipo", availabilityByType);
            
            return Response.ok(ApiResponse.success("Estadísticas de tickets", stats)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener estadísticas: " + e.getMessage()))
                .build();
        }
    }
}

// Made with Bob
