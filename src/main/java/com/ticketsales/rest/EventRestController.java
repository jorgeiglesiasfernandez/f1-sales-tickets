package com.ticketsales.rest;

import com.ticketsales.dto.ApiResponse;
import com.ticketsales.dto.EventDTO;
import com.ticketsales.model.Event;
import com.ticketsales.repository.EventRepository;

import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

/**
 * Controlador REST para operaciones con eventos
 * Base path: /api/events
 */
@Path("/events")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class EventRestController {
    
    private final EventRepository eventRepository;
    
    public EventRestController() {
        this.eventRepository = EventRepository.getInstance();
    }
    
    /**
     * GET /api/events
     * Obtiene información del evento actual
     */
    @GET
    public Response getEvent() {
        try {
            Event event = eventRepository.getEvent();
            if (event == null) {
                return Response.status(Response.Status.NOT_FOUND)
                    .entity(ApiResponse.error("No hay eventos disponibles"))
                    .build();
            }
            
            EventDTO eventDTO = new EventDTO(event);
            return Response.ok(ApiResponse.success(eventDTO)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener el evento: " + e.getMessage()))
                .build();
        }
    }
    
    /**
     * GET /api/events/{id}
     * Obtiene información de un evento específico por ID
     */
    @GET
    @Path("/{id}")
    public Response getEventById(@PathParam("id") String id) {
        try {
            Event event = eventRepository.getEvent();
            
            if (event == null || !event.getId().equals(id)) {
                return Response.status(Response.Status.NOT_FOUND)
                    .entity(ApiResponse.error("Evento no encontrado con ID: " + id))
                    .build();
            }
            
            EventDTO eventDTO = new EventDTO(event);
            return Response.ok(ApiResponse.success(eventDTO)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener el evento: " + e.getMessage()))
                .build();
        }
    }
    
    /**
     * GET /api/events/availability
     * Obtiene información de disponibilidad del evento
     */
    @GET
    @Path("/availability")
    public Response getAvailability() {
        try {
            Event event = eventRepository.getEvent();
            if (event == null) {
                return Response.status(Response.Status.NOT_FOUND)
                    .entity(ApiResponse.error("No hay eventos disponibles"))
                    .build();
            }
            
            // Crear un objeto con información de disponibilidad
            java.util.Map<String, Object> availability = new java.util.HashMap<>();
            availability.put("eventId", event.getId());
            availability.put("eventName", event.getNombre());
            availability.put("capacidadTotal", event.getCapacidadTotal());
            availability.put("entradasVendidas", event.getEntradasVendidas());
            availability.put("entradasDisponibles", event.getEntradasDisponibles());
            availability.put("porcentajeVendido", event.getPorcentajeVendido());
            availability.put("agotado", event.getEntradasDisponibles() == 0);
            
            return Response.ok(ApiResponse.success("Disponibilidad del evento", availability)).build();
            
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiResponse.error("Error al obtener disponibilidad: " + e.getMessage()))
                .build();
        }
    }
}

// Made with Bob
