package com.ticketsales.rest;

import com.ticketsales.dto.ApiResponse;
import com.ticketsales.dto.TicketAvailabilityDTO;
import com.ticketsales.dto.TicketCreateRequestDTO;
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
     * POST /api/tickets
     * Crea un nuevo ticket de forma idempotente (ON CONFLICT DO NOTHING).
     *
     * Body JSON:
     * {
     *   "eventId":  "F1-2026-ESP",
     *   "tipo":     "VIP" | "GENERAL",
     *   "asiento":  "V3-A01",
     *   "seccion":  "V3"
     * }
     *
     * Respuestas:
     *   201 Created  — ticket creado
     *   200 OK       — ticket ya existía (idempotente)
     *   400          — datos inválidos
     */
    @POST
    public Response createTicket(TicketCreateRequestDTO request) {
        try {
            if (request == null) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("Datos del ticket requeridos"))
                    .build();
            }

            if (request.getTipo() == null || request.getTipo().trim().isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("El campo 'tipo' es requerido (GENERAL o VIP)"))
                    .build();
            }

            if (request.getAsiento() == null || request.getAsiento().trim().isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("El campo 'asiento' es requerido"))
                    .build();
            }

            if (request.getSeccion() == null || request.getSeccion().trim().isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("El campo 'seccion' es requerido"))
                    .build();
            }

            TipoEntrada tipoEntrada;
            try {
                tipoEntrada = TipoEntrada.valueOf(request.getTipo().toUpperCase());
            } catch (IllegalArgumentException e) {
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiResponse.error("Tipo de entrada inválido. Use: GENERAL o VIP"))
                    .build();
            }

            String eventId = (request.getEventId() != null && !request.getEventId().isEmpty())
                ? request.getEventId()
                : "F1-2026-ESP";

            // Generar ID determinista a partir de tipo, sección y asiento
            String ticketId = "TKT-API-" + request.getSeccion() + "-"
                + request.getAsiento().replaceAll("[^A-Za-z0-9]", "");

            Ticket ticket = new Ticket(ticketId, eventId, tipoEntrada,
                request.getAsiento(), request.getSeccion());

            Ticket created = ticketRepository.createTicket(ticket);

            TicketDTO dto = new TicketDTO(ticket);
            if (created != null) {
                return Response.status(Response.Status.CREATED)
                    .entity(ApiResponse.success("Ticket creado", dto))
                    .build();
            } else {
                return Response.ok(ApiResponse.success("Ticket ya existía (sin cambios)", dto)).build();
            }

        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al crear el ticket: " + e.getMessage()))
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
