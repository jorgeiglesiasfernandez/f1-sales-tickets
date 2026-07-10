package com.ticketsales.repository;

import com.ticketsales.model.Purchase;
import com.ticketsales.model.Ticket;
import com.ticketsales.util.DatabaseConnection;

import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Repositorio para gestionar compras en la base de datos MySQL
 */
public class PurchaseRepository {
    private static final Logger LOGGER = Logger.getLogger(PurchaseRepository.class.getName());
    private static PurchaseRepository instance;
    private static final String EVENT_ID = "F1-2026-ESP";
    
    private PurchaseRepository() {
        // Constructor privado para patrón Singleton
    }
    
    public static synchronized PurchaseRepository getInstance() {
        if (instance == null) {
            instance = new PurchaseRepository();
        }
        return instance;
    }
    
    /**
     * Crea una nueva compra en la base de datos
     */
    public synchronized Purchase createPurchase(Purchase purchase) {
        Connection conn = null;
        PreparedStatement purchaseStmt = null;
        PreparedStatement ticketStmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            conn.setAutoCommit(false);
            
            // Generar ID si no existe
            if (purchase.getId() == null || purchase.getId().isEmpty()) {
                purchase.setId(generatePurchaseId());
            }
            
            // Calcular precio total
            purchase.calcularPrecioTotal();
            
            // Generar código de confirmación
            purchase.confirmar();
            
            // Insertar compra
            String purchaseSql = "INSERT INTO purchases (id, event_id, nombre_comprador, email, telefono, " +
                               "cantidad_entradas, tipo_entrada, precio_total, estado, codigo_confirmacion) " +
                               "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
            
            purchaseStmt = conn.prepareStatement(purchaseSql);
            purchaseStmt.setString(1, purchase.getId());
            purchaseStmt.setString(2, EVENT_ID);
            purchaseStmt.setString(3, purchase.getNombreComprador());
            purchaseStmt.setString(4, purchase.getEmail());
            purchaseStmt.setString(5, purchase.getTelefono());
            purchaseStmt.setInt(6, purchase.getCantidadEntradas());
            purchaseStmt.setString(7, purchase.getTipoEntrada().name());
            purchaseStmt.setBigDecimal(8, purchase.getPrecioTotal());
            purchaseStmt.setString(9, purchase.getEstado());
            purchaseStmt.setString(10, purchase.getCodigoConfirmacion());
            
            purchaseStmt.executeUpdate();
            
            // Insertar relaciones con tickets si existen asientos asignados
            if (purchase.getAsientosAsignados() != null && !purchase.getAsientosAsignados().isEmpty()) {
                String ticketSql = "INSERT INTO purchase_tickets (purchase_id, ticket_id) " +
                                 "SELECT ?, id FROM tickets WHERE asiento = ? AND event_id = ? LIMIT 1";
                ticketStmt = conn.prepareStatement(ticketSql);
                
                for (String asiento : purchase.getAsientosAsignados()) {
                    ticketStmt.setString(1, purchase.getId());
                    ticketStmt.setString(2, asiento);
                    ticketStmt.setString(3, EVENT_ID);
                    ticketStmt.addBatch();
                }
                
                ticketStmt.executeBatch();
            }
            
            conn.commit();
            LOGGER.info("Compra creada exitosamente: " + purchase.getId());
            
            return purchase;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al crear compra", e);
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
            if (purchaseStmt != null) try { purchaseStmt.close(); } catch (SQLException e) { }
            if (ticketStmt != null) try { ticketStmt.close(); } catch (SQLException e) { }
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
     * Busca una compra por ID
     */
    public Purchase findById(String id) {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT p.id, p.event_id, p.nombre_comprador, p.email, p.telefono, " +
                        "p.cantidad_entradas, p.tipo_entrada, p.precio_total, p.fecha_compra, " +
                        "p.estado, p.codigo_confirmacion, " +
                        "STRING_AGG(t.asiento, ',' ORDER BY t.asiento) AS asientos " +
                        "FROM purchases p " +
                        "LEFT JOIN purchase_tickets pt ON p.id = pt.purchase_id " +
                        "LEFT JOIN tickets t ON pt.ticket_id = t.id " +
                        "WHERE p.id = ? " +
                        "GROUP BY p.id";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, id);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return mapResultSetToPurchase(rs);
            }
            
            return null;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al buscar compra por ID", e);
            return null;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene todas las compras
     */
    public List<Purchase> findAll() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        List<Purchase> purchases = new ArrayList<>();
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT p.id, p.event_id, p.nombre_comprador, p.email, p.telefono, " +
                        "p.cantidad_entradas, p.tipo_entrada, p.precio_total, p.fecha_compra, " +
                        "p.estado, p.codigo_confirmacion, " +
                        "STRING_AGG(t.asiento, ',' ORDER BY t.asiento) AS asientos " +
                        "FROM purchases p " +
                        "LEFT JOIN purchase_tickets pt ON p.id = pt.purchase_id " +
                        "LEFT JOIN tickets t ON pt.ticket_id = t.id " +
                        "GROUP BY p.id " +
                        "ORDER BY p.fecha_compra DESC";
            
            stmt = conn.prepareStatement(sql);
            rs = stmt.executeQuery();
            
            while (rs.next()) {
                purchases.add(mapResultSetToPurchase(rs));
            }
            
            return purchases;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener todas las compras", e);
            return purchases;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Busca compras por email
     */
    public List<Purchase> findByEmail(String email) {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        List<Purchase> purchases = new ArrayList<>();
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT p.id, p.event_id, p.nombre_comprador, p.email, p.telefono, " +
                        "p.cantidad_entradas, p.tipo_entrada, p.precio_total, p.fecha_compra, " +
                        "p.estado, p.codigo_confirmacion, " +
                        "STRING_AGG(t.asiento, ',' ORDER BY t.asiento) AS asientos " +
                        "FROM purchases p " +
                        "LEFT JOIN purchase_tickets pt ON p.id = pt.purchase_id " +
                        "LEFT JOIN tickets t ON pt.ticket_id = t.id " +
                        "WHERE p.email = ? " +
                        "GROUP BY p.id " +
                        "ORDER BY p.fecha_compra DESC";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, email);
            rs = stmt.executeQuery();
            
            while (rs.next()) {
                purchases.add(mapResultSetToPurchase(rs));
            }
            
            return purchases;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al buscar compras por email", e);
            return purchases;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Busca compras por estado
     */
    public List<Purchase> findByEstado(String estado) {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        List<Purchase> purchases = new ArrayList<>();
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT p.id, p.event_id, p.nombre_comprador, p.email, p.telefono, " +
                        "p.cantidad_entradas, p.tipo_entrada, p.precio_total, p.fecha_compra, " +
                        "p.estado, p.codigo_confirmacion, " +
                        "STRING_AGG(t.asiento, ',' ORDER BY t.asiento) AS asientos " +
                        "FROM purchases p " +
                        "LEFT JOIN purchase_tickets pt ON p.id = pt.purchase_id " +
                        "LEFT JOIN tickets t ON pt.ticket_id = t.id " +
                        "WHERE p.estado = ? " +
                        "GROUP BY p.id " +
                        "ORDER BY p.fecha_compra DESC";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, estado);
            rs = stmt.executeQuery();
            
            while (rs.next()) {
                purchases.add(mapResultSetToPurchase(rs));
            }
            
            return purchases;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al buscar compras por estado", e);
            return purchases;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene las compras más recientes
     */
    public List<Purchase> getRecentPurchases(int limit) {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        List<Purchase> purchases = new ArrayList<>();
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT p.id, p.event_id, p.nombre_comprador, p.email, p.telefono, " +
                        "p.cantidad_entradas, p.tipo_entrada, p.precio_total, p.fecha_compra, " +
                        "p.estado, p.codigo_confirmacion, " +
                        "STRING_AGG(t.asiento, ',' ORDER BY t.asiento) AS asientos " +
                        "FROM purchases p " +
                        "LEFT JOIN purchase_tickets pt ON p.id = pt.purchase_id " +
                        "LEFT JOIN tickets t ON pt.ticket_id = t.id " +
                        "GROUP BY p.id " +
                        "ORDER BY p.fecha_compra DESC " +
                        "LIMIT ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setInt(1, limit);
            rs = stmt.executeQuery();
            
            while (rs.next()) {
                purchases.add(mapResultSetToPurchase(rs));
            }
            
            return purchases;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener compras recientes", e);
            return purchases;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Actualiza una compra
     */
    public void updatePurchase(Purchase purchase) {
        Connection conn = null;
        PreparedStatement stmt = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "UPDATE purchases SET nombre_comprador = ?, email = ?, telefono = ?, " +
                        "cantidad_entradas = ?, tipo_entrada = ?, precio_total = ?, estado = ?, " +
                        "codigo_confirmacion = ? WHERE id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, purchase.getNombreComprador());
            stmt.setString(2, purchase.getEmail());
            stmt.setString(3, purchase.getTelefono());
            stmt.setInt(4, purchase.getCantidadEntradas());
            stmt.setString(5, purchase.getTipoEntrada().name());
            stmt.setBigDecimal(6, purchase.getPrecioTotal());
            stmt.setString(7, purchase.getEstado());
            stmt.setString(8, purchase.getCodigoConfirmacion());
            stmt.setString(9, purchase.getId());
            
            stmt.executeUpdate();
            LOGGER.info("Compra actualizada: " + purchase.getId());
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al actualizar compra", e);
        } finally {
            DatabaseConnection.closeResources(conn, stmt, null);
        }
    }
    
    /**
     * Elimina una compra
     */
    public boolean deletePurchase(String id) {
        Connection conn = null;
        PreparedStatement stmt = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "DELETE FROM purchases WHERE id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, id);
            
            int rowsAffected = stmt.executeUpdate();
            LOGGER.info("Compra eliminada: " + id);
            
            return rowsAffected > 0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al eliminar compra", e);
            return false;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, null);
        }
    }
    
    /**
     * Obtiene el total de compras
     */
    public int getTotalPurchases() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT COUNT(*) AS total FROM purchases WHERE event_id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getInt("total");
            }
            
            return 0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener total de compras", e);
            return 0;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene el total de tickets vendidos
     */
    public int getTotalTicketsSold() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT SUM(cantidad_entradas) AS total FROM purchases " +
                        "WHERE event_id = ? AND estado = 'CONFIRMADA'";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getInt("total");
            }
            
            return 0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener total de tickets vendidos", e);
            return 0;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene los ingresos totales
     */
    public BigDecimal getTotalRevenue() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT SUM(precio_total) AS total FROM purchases " +
                        "WHERE event_id = ? AND estado = 'CONFIRMADA'";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                BigDecimal total = rs.getBigDecimal("total");
                return total != null ? total : BigDecimal.ZERO;
            }
            
            return BigDecimal.ZERO;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener ingresos totales", e);
            return BigDecimal.ZERO;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene las ventas por tipo de entrada
     */
    public Map<String, Integer> getSalesByType() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        Map<String, Integer> salesByType = new HashMap<>();
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT tipo_entrada, SUM(cantidad_entradas) AS total FROM purchases " +
                        "WHERE event_id = ? AND estado = 'CONFIRMADA' " +
                        "GROUP BY tipo_entrada";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            while (rs.next()) {
                salesByType.put(rs.getString("tipo_entrada"), rs.getInt("total"));
            }
            
            return salesByType;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener ventas por tipo", e);
            return salesByType;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Obtiene el promedio de tickets por compra
     */
    public double getAverageTicketsPerPurchase() {
        Connection conn = null;
        PreparedStatement stmt = null;
        ResultSet rs = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "SELECT AVG(cantidad_entradas) AS promedio FROM purchases " +
                        "WHERE event_id = ? AND estado = 'CONFIRMADA'";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            rs = stmt.executeQuery();
            
            if (rs.next()) {
                return rs.getDouble("promedio");
            }
            
            return 0.0;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al obtener promedio de tickets por compra", e);
            return 0.0;
        } finally {
            DatabaseConnection.closeResources(conn, stmt, rs);
        }
    }
    
    /**
     * Resetea todas las compras (solo para pruebas)
     */
    public synchronized void resetPurchases() {
        Connection conn = null;
        PreparedStatement stmt = null;
        
        try {
            conn = DatabaseConnection.getConnection();
            String sql = "DELETE FROM purchases WHERE event_id = ?";
            
            stmt = conn.prepareStatement(sql);
            stmt.setString(1, EVENT_ID);
            int rowsAffected = stmt.executeUpdate();
            
            LOGGER.info("Compras reseteadas: " + rowsAffected);
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al resetear compras", e);
        } finally {
            DatabaseConnection.closeResources(conn, stmt, null);
        }
    }
    
    /**
     * Resetea todas las compras en una única transacción atómica:
     *   1. Borra purchase_tickets (relaciones compra-ticket)
     *   2. Borra purchases (todas las compras)
     *   3. Libera todos los tickets (disponible = TRUE)
     *   4. Resetea entradas_vendidas = 0 en el evento
     *
     * @return mapa con contadores de filas afectadas por operación
     */
    public synchronized java.util.Map<String, Integer> resetAll() {
        Connection conn = null;
        java.util.Map<String, Integer> result = new java.util.LinkedHashMap<>();
        try {
            conn = DatabaseConnection.getConnection();
            conn.setAutoCommit(false);

            try (Statement stmt = conn.createStatement()) {
                result.put("purchaseTicketsDeleted",
                    stmt.executeUpdate("DELETE FROM purchase_tickets"));
                result.put("purchasesDeleted",
                    stmt.executeUpdate("DELETE FROM purchases"));
                result.put("ticketsReleased",
                    stmt.executeUpdate(
                        "UPDATE tickets SET disponible = TRUE WHERE disponible = FALSE"));
                result.put("eventCounterReset",
                    stmt.executeUpdate(
                        "UPDATE events SET entradas_vendidas = 0 WHERE id = '" + EVENT_ID + "'"));
            }

            conn.commit();
            LOGGER.info("Reset completo: " + result);
            return result;

        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error al ejecutar resetAll", e);
            if (conn != null) {
                try { conn.rollback(); } catch (SQLException ex) {
                    LOGGER.log(Level.SEVERE, "Error en rollback de resetAll", ex);
                }
            }
            throw new RuntimeException("Error al resetear compras: " + e.getMessage(), e);
        } finally {
            if (conn != null) {
                try { conn.setAutoCommit(true); conn.close(); }
                catch (SQLException e) {
                    LOGGER.log(Level.WARNING, "Error al cerrar conexión en resetAll", e);
                }
            }
        }
    }

    /**
     * Genera un ID único para la compra
     */
    private String generatePurchaseId() {
        return "PUR-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }

    /**
     * Mapea un ResultSet a un objeto Purchase
     */
    private Purchase mapResultSetToPurchase(ResultSet rs) throws SQLException {
        Purchase purchase = new Purchase();
        purchase.setId(rs.getString("id"));
        purchase.setEventId(rs.getString("event_id"));
        purchase.setNombreComprador(rs.getString("nombre_comprador"));
        purchase.setEmail(rs.getString("email"));
        purchase.setTelefono(rs.getString("telefono"));
        purchase.setCantidadEntradas(rs.getInt("cantidad_entradas"));
        
        String tipoStr = rs.getString("tipo_entrada");
        purchase.setTipoEntrada(Ticket.TipoEntrada.valueOf(tipoStr));
        
        purchase.setPrecioTotal(rs.getBigDecimal("precio_total"));
        purchase.setFechaCompra(rs.getTimestamp("fecha_compra"));
        purchase.setEstado(rs.getString("estado"));
        purchase.setCodigoConfirmacion(rs.getString("codigo_confirmacion"));
        
        // Procesar asientos asignados
        String asientos = rs.getString("asientos");
        if (asientos != null && !asientos.isEmpty()) {
            List<String> asientosList = Arrays.asList(asientos.split(","));
            purchase.setAsientosAsignados(asientosList);
        }
        
        return purchase;
    }
}

// Made with Bob