package com.ticketsales.repository;

import com.ticketsales.model.Ticket;
import com.ticketsales.model.Ticket.TipoEntrada;
import com.ticketsales.util.DatabaseConnection;

import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Repositorio para gestionar tickets en la base de datos MySQL
 */
public class TicketRepository {
    private static final Logger LOGGER = Logger.getLogger(TicketRepository.class.getName());
    private static TicketRepository instance;
    private static final String EVENT_ID = "F1-2026-ESP";
    
    private TicketRepository() {
        // Constructor privado para patrón Singleton
    }
    
    public static synchronized TicketRepository getInstance() {
        if (instance == null) {
            instance = new TicketRepository();
        }
        return instance;
    }
    
    /**
     * Obtiene todos los tickets disponibles
     */
    public List<Ticket> getAvailableTickets() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        List<Ticket> tickets = new ArrayList<>();
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT id, event_id, tipo, precio, asiento, seccion, disponible " +
                        "FROM tickets WHERE event_id = ? AND disponible = TRUE " +
                        "ORDER BY tipo, seccion, asiento";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            while (rs.next()) {
                tickets.add(mapResultSetToTicket(rs));
            }
            
            LOGGER.info("Tickets disponibles encontrados: " + tickets.size());
            return tickets;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener tickets disponibles", e);
            return tickets;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene tickets disponibles por tipo
     */
    public List<Ticket> getAvailableTicketsByType(TipoEntrada tipo) {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        List<Ticket> tickets = new ArrayList<>();
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT id, event_id, tipo, precio, asiento, seccion, disponible " +
                        "FROM tickets WHERE event_id = ? AND tipo = ? AND disponible = TRUE " +
                        "ORDER BY seccion, asiento";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            stmt.setString(2, tipo.name());
            rs = stmt.executeQuery();
            
            while (rs.next()) {
                tickets.add(mapResultSetToTicket(rs));
            }
            
            LOGGER.info("Tickets " + tipo + " disponibles: " + tickets.size());
            return tickets;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener tickets por tipo", e);
            return tickets;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Cuenta tickets disponibles por tipo
     */
    public long countAvailableByType(TipoEntrada tipo) {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT COUNT(*) AS total FROM tickets " +
                        "WHERE event_id = ? AND tipo = ? AND disponible = TRUE";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            stmt.setString(2, tipo.name());
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getLong("total");
            }
            
            return 0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al contar tickets por tipo", e);
            return 0;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Reserva tickets de un tipo específico
     */
    public synchronized List<Ticket> reserveTickets(TipoEntrada tipo, int cantidad) {
        Connection conn = null;
        PreparedStatement selectStmt = null;
        PreparedStatement updateStmt = null;
        ResultSet rs = null;
        List<Ticket> reservedTickets = new ArrayList<>();
        
        try {
            conn = DatabaseConnection.getConnection();
            conn.setAutoCommit(false);
            
            // Seleccionar tickets disponibles con bloqueo
            String selectSql = "SELECT id, event_id, tipo, precio, asiento, seccion, disponible " +
                             "FROM tickets WHERE event_id = ? AND tipo = ? AND disponible = TRUE " +
                             "ORDER BY seccion, asiento LIMIT ? FOR UPDATE";
            
            selectStmt = conn.prepareStatement(selectSql);
            selectStmt.setString(1, EVENT_ID);
            selectStmt.setString(2, tipo.name());
            selectStmt.setInt(3, cantidad);
            rs = selectStmt.executeQuery();
            
            // Recopilar IDs de tickets a reservar
            List<String> ticketIds = new ArrayList<>();
            while (rs.next()) {
                Ticket ticket = mapResultSetToTicket(rs);
                reservedTickets.add(ticket);
                ticketIds.add(ticket.getId());
            }
            
            // Verificar si hay suficientes tickets
            if (reservedTickets.size() < cantidad) {
                conn.rollback();
                LOGGER.warning("No hay suficientes tickets " + tipo + ". Disponibles: " + 
                             reservedTickets.size() + ", Solicitados: " + cantidad);
                return null;
            }
            
            // Marcar tickets como no disponibles
            String updateSql = "UPDATE tickets SET disponible = FALSE WHERE id = ?";
            updateStmt = conn.prepareStatement(updateSql);
            
            for (String ticketId : ticketIds) {
                updateStmt.setString(1, ticketId);
                updateStmt.addBatch();
            }
            
            updateStmt.executeBatch();
            conn.commit();
            
            LOGGER.info("Tickets reservados exitosamente: " + reservedTickets.size());
            return reservedTickets;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al reservar tickets", e);
            if (conn != null) {
                try {
                    conn.rollback();
                } catch (SQLException ex) {
                    LOGGER.log(Level.SEVERE, "Error al hacer rollback", ex);
                }
            }
            return null;
        } finally {
            if (rs != null) try { rs.close(); } catch (SQLException e) { }
            if (selectStmt != null) try { selectStmt.close(); } catch (SQLException e) { }
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
     * Libera tickets (los marca como disponibles nuevamente)
     */
    public synchronized boolean releaseTickets(List<String> ticketIds) {
        if (ticketIds == null || ticketIds.isEmpty()) {
            return true;
        }
        
        Connection conn = null;
        PreparedStatement stmt = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            conn.setAutoCommit(false);
            
            String sql = "UPDATE tickets SET disponible = TRUE WHERE id = ?";
            stmt = conn.prepareStatement(sql);
            
            for (String ticketId : ticketIds) {
                stmt.setString(1, ticketId);
                stmt.addBatch();
            }
            
            stmt.executeBatch();
            conn.commit();
            
            LOGGER.info("Tickets liberados: " + ticketIds.size());
            return true;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al liberar tickets", e);
            if (conn != null) {
                try {
                    conn.rollback();
                } catch (SQLException ex) {
                    LOGGER.log(Level.SEVERE, "Error al hacer rollback", ex);
                }
            }
            return false;
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
    
    /**
     * Busca un ticket por ID
     */
    public Ticket findById(String id) {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT id, event_id, tipo, precio, asiento, seccion, disponible " +
                        "FROM tickets WHERE id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, id);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return mapResultSetToTicket(rs);
            }
            
            return null;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al buscar ticket por ID", e);
            return null;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene la capacidad restante total
     */
    public int getRemainingCapacity() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT COUNT(*) AS total FROM tickets " +
                        "WHERE event_id = ? AND disponible = TRUE";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getInt("total");
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
     * Obtiene la capacidad total
     */
    public int getTotalCapacity() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT COUNT(*) AS total FROM tickets WHERE event_id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getInt("total");
            }
            
            return 0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener capacidad total", e);
            return 0;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene el número de tickets vendidos
     */
    public int getSoldTickets() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT COUNT(*) AS total FROM tickets " +
                        "WHERE event_id = ? AND disponible = FALSE";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getInt("total");
            }
            
            return 0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener tickets vendidos", e);
            return 0;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene la disponibilidad por tipo de entrada
     */
    public Map<TipoEntrada, Long> getAvailabilityByType() {
        Map<TipoEntrada, Long> availability = new HashMap<>();
        availability.put(TipoEntrada.GENERAL, countAvailableByType(TipoEntrada.GENERAL));
        availability.put(TipoEntrada.VIP, countAvailableByType(TipoEntrada.VIP));
        return availability;
    }
    
    /**
     * Resetea todos los tickets (los marca como disponibles)
     * ADVERTENCIA: Este método es solo para pruebas
     */
    public synchronized void resetTickets() {
        Connection conn = null;
        PreparedStatement stmt = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "UPDATE tickets SET disponible = TRUE WHERE event_id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            int rowsAffected = stmt.executeUpdate();
            
            LOGGER.info("Tickets reseteados: " + rowsAffected);
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al resetear tickets", e);
        } finally {
            DatabaseConnection.closeResources(conn, stmt, null);
        }
    }
    
    /**
     * Mapea un ResultSet a un objeto Ticket
     */
    private Ticket mapResultSetToTicket(ResultSet rs) throws SQLException {
        Ticket ticket = new Ticket();
        ticket.setId(rs.getString("id"));
        ticket.setEventId(rs.getString("event_id"));
        
        String tipoStr = rs.getString("tipo");
        ticket.setTipo(TipoEntrada.valueOf(tipoStr));
        
        ticket.setPrecio(rs.getBigDecimal("precio"));
        ticket.setAsiento(rs.getString("asiento"));
        ticket.setSeccion(rs.getString("seccion"));
        ticket.setDisponible(rs.getBoolean("disponible"));
        
        return ticket;
    }
}

// Made with Bob