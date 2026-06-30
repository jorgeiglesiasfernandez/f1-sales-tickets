package com.ticketsales.rest;

import javax.ws.rs.ApplicationPath;
import javax.ws.rs.core.Application;
import java.util.HashSet;
import java.util.Set;

/**
 * Configuración de la aplicación JAX-RS
 * Define el path base para todos los endpoints REST: /api
 */
@ApplicationPath("/api")
public class RestApplication extends Application {
    
    @Override
    public Set<Class<?>> getClasses() {
        Set<Class<?>> classes = new HashSet<>();
        
        // Registrar controladores REST
        classes.add(EventRestController.class);
        classes.add(TicketRestController.class);
        classes.add(PurchaseRestController.class);
        
        return classes;
    }
}

// Made with Bob
