package com.ticketsales.repository;

import com.ticketsales.model.Event;
import com.ticketsales.util.DatabaseConnection;

import java.sql.*;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Repositorio para gestionar eventos en la base de datos MySQL
 */
public class EventRepository {
    private static final Logger LOGGER = Logger.getLogger(EventRepository.class.getName());
    private static EventRepository instance;
    private static final String EVENT_ID = "F1-2026-ESP";
    
    private EventRepository() {
        // Constructor privado para patrón Singleton
    }
    
    public static synchronized EventRepository getInstance() {
        if (instance == null) {
            instance = new EventRepository();
        }
        return instance;
    }
    
    /**
     * Obtiene el evento principal desde la base de datos
     */
    public Event getEvent() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT id, nombre, fecha, circuito, ubicacion, capacidad_total, " +
                        "entradas_vendidas, descripcion FROM events WHERE id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                Event event = new Event();
                event.setId(rs.getString("id"));
                event.setNombre(rs.getString("nombre"));
                event.setFecha(rs.getTimestamp("fecha"));
                event.setCircuito(rs.getString("circuito"));
                event.setUbicacion(rs.getString("ubicacion"));
                event.setCapacidadTotal(rs.getInt("capacidad_total"));
                event.setEntradasVendidas(rs.getInt("entradas_vendidas"));
                event.setDescripcion(rs.getString("descripcion"));
                
                return event;
            }
            
            LOGGER.warning("No se encontró el evento con ID: " + EVENT_ID);
            return null;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener el evento", e);
            return null;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Actualiza el contador de entradas vendidas
     */
    public synchronized boolean updateSoldTickets(int cantidad) {
        Connection conn = null;
        PreparedStatement checkStmt = null;
        PreparedStatement updateStmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            conn.setAutoCommit(false);
            
            // Verificar disponibilidad
            String checkSql = "SELECT capacidad_total, entradas_vendidas FROM events WHERE id = ? FOR UPDATE";
            checkStmt = conn.prepareStatement(checkSql);
            checkStmt.setString(1, EVENT_ID);
            rs = checkStmt.executeQuery();
            
            if (rs.next()) {
                int capacidadTotal = rs.getInt("capacidad_total");
                int entradasVendidas = rs.getInt("entradas_vendidas");
                
                if ((entradasVendidas + cantidad) > capacidadTotal) {
                    conn.rollback();
                    LOGGER.warning("No hay suficiente capacidad. Disponible: " + 
                                 (capacidadTotal - entradasVendidas) + ", Solicitado: " + cantidad);
                    return false;
                }
                
                // Actualizar entradas vendidas
                String updateSql = "UPDATE events SET entradas_vendidas = entradas_vendidas + ? WHERE id = ?";
                updateStmt = conn.prepareStatement(updateSql);
                updateStmt.setInt(1, cantidad);
                updateStmt.setString(2, EVENT_ID);
                
                int rowsAffected = updateStmt.executeUpdate();
                
                if (rowsAffected > 0) {
                    conn.commit();
                    LOGGER.info("Entradas vendidas actualizadas: +" + cantidad);
                    return true;
                } else {
                    conn.rollback();
                    return false;
                }
            } else {
                conn.rollback();
                LOGGER.warning("Evento no encontrado: " + EVENT_ID);
                return false;
            }
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al actualizar entradas vendidas", e);
            if (conn != null) {
                try {
                    conn.rollback();
                } catch (SQLException ex) {
                    LOGGER.log(Level.SEVERE, "Error al hacer rollback", ex);
                }
            }
            return false;
        } finally {
            if (rs != null) try { rs.close(); } catch (SQLException e) { }
            if (checkStmt != null) try { checkStmt.close(); } catch (SQLException e) { }
            if (updateStmt != null) try { updateStmt.close(); } catch (SQLException e) { }
            if (conn != null) {
                try {
                    conn.setAutoCommit(true);
                    conn.close();
                } catch (SQLException e) {
                    LOGGER.log(Level.WARNING, "Error al cerrar conexión", e);
                }
            }
        }
    }
    
    /**
     * Verifica si hay capacidad disponible
     */
    public boolean checkCapacity(int cantidad) {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT (capacidad_total - entradas_vendidas) AS disponible FROM events WHERE id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                int disponible = rs.getInt("disponible");
                return disponible >= cantidad;
            }
            
            return false;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al verificar capacidad", e);
            return false;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene la capacidad restante
     */
    public int getRemainingCapacity() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT (capacidad_total - entradas_vendidas) AS disponible FROM events WHERE id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getInt("disponible");
            }
            
            return 0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener capacidad restante", e);
            return 0;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene el total de entradas vendidas
     */
    public int getTotalSold() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT entradas_vendidas FROM events WHERE id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getInt("entradas_vendidas");
            }
            
            return 0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener total vendido", e);
            return 0;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene el porcentaje de entradas vendidas
     */
    public double getPercentageSold() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT (entradas_vendidas * 100.0 / capacidad_total) AS porcentaje " +
                        "FROM events WHERE id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getDouble("porcentaje");
            }
            
            return 0.0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener porcentaje vendido", e);
            return 0.0;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Verifica si el evento está agotado
     */
    public boolean isSoldOut() {
        return getRemainingCapacity() == 0;
    }
    
    /**
     * Resetea el evento (útil para pruebas)
     * ADVERTENCIA: Este método elimina todas las compras y resetea los contadores
     */
    public synchronized void resetEvent() {
        Connection conn = null;
        PreparedStatement stmt = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            conn.setAutoCommit(false);
            
            // Resetear entradas vendidas
            String sql = "UPDATE events SET entradas_vendidas = 0 WHERE id = ?";
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            stmt.executeUpdate();
            
            conn.commit();
            LOGGER.info("Evento reseteado correctamente");
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al resetear evento", e);
            if (conn != null) {
                try {
                    conn.rollback();
                } catch (SQLException ex) {
                    LOGGER.log(Level.SEVERE, "Error al hacer rollback", ex);
                }
            }
        } finally {
            if (stmt != null) try { stmt.close(); } catch (SQLException e) { }
            if (conn != null) {
                try {
                    conn.setAutoCommit(true);
                    conn.close();
                } catch (SQLException e) {
                    LOGGER.log(Level.WARNING, "Error al cerrar conexión", e);
                }
            }
        }
    }
}

// Made with Bob