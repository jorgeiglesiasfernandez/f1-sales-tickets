package com.ticketsales.util;

import javax.naming.Context;
import javax.naming.InitialContext;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Clase utilitaria para gestionar conexiones a la base de datos PostgreSQL.
 * Utiliza el DataSource configurado en Liberty mediante JNDI.
 */
public class DatabaseConnection {
    private static final Logger LOGGER = Logger.getLogger(DatabaseConnection.class.getName());

    // Liberty registra el DataSource bajo el nombre corto del server.xml;
    // la app lo resuelve vía resource-ref declarado en web.xml.
    // Se prueban ambas rutas para cubrir entornos locales y OCP.
    private static final String[] JNDI_CANDIDATES = {
        "java:comp/env/jdbc/AppDS",
        "jdbc/AppDS"
    };

    private static volatile DataSource dataSource;

    /**
     * Lookup lazy: se resuelve la primera vez que se pide una conexión,
     * cuando Liberty ya ha completado el binding JNDI de la aplicación.
     */
    private static DataSource getDataSource() throws SQLException {
        if (dataSource == null) {
            synchronized (DatabaseConnection.class) {
                if (dataSource == null) {
                    for (String jndiName : JNDI_CANDIDATES) {
                        try {
                            Context ctx = new InitialContext();
                            dataSource = (DataSource) ctx.lookup(jndiName);
                            LOGGER.info("DataSource inicializado correctamente: " + jndiName);
                            break;
                        } catch (Exception e) {
                            LOGGER.log(Level.WARNING, "JNDI lookup fallido para: " + jndiName, e);
                        }
                    }
                    if (dataSource == null) {
                        throw new SQLException(
                            "DataSource no disponible. Comprueba la configuración JNDI en server.xml y web.xml.");
                    }
                }
            }
        }
        return dataSource;
    }

    /**
     * Obtiene una conexión a la base de datos desde el pool de conexiones
     *
     * @return Connection objeto de conexión a la base de datos
     * @throws SQLException si hay un error al obtener la conexión
     */
    public static Connection getConnection() throws SQLException {
        Connection conn = getDataSource().getConnection();
        
        if (conn == null) {
            throw new SQLException("No se pudo obtener una conexión del DataSource");
        }
        
        // Configurar la conexión
        conn.setAutoCommit(true);
        
        LOGGER.fine("Conexión obtenida exitosamente");
        return conn;
    }
    
    /**
     * Cierra una conexión de forma segura
     * 
     * @param conn conexión a cerrar
     */
    public static void closeConnection(Connection conn) {
        if (conn != null) {
            try {
                if (!conn.isClosed()) {
                    conn.close();
                    LOGGER.fine("Conexión cerrada exitosamente");
                }
            } catch (SQLException e) {
                LOGGER.log(Level.WARNING, "Error al cerrar la conexión", e);
            }
        }
    }
    
    /**
     * Cierra recursos de base de datos de forma segura
     * 
     * @param conn conexión a cerrar
     * @param stmt statement a cerrar
     * @param rs result set a cerrar
     */
    public static void closeResources(Connection conn, java.sql.Statement stmt, java.sql.ResultSet rs) {
        if (rs != null) {
            try {
                rs.close();
            } catch (SQLException e) {
                LOGGER.log(Level.WARNING, "Error al cerrar ResultSet", e);
            }
        }
        
        if (stmt != null) {
            try {
                stmt.close();
            } catch (SQLException e) {
                LOGGER.log(Level.WARNING, "Error al cerrar Statement", e);
            }
        }
        
        closeConnection(conn);
    }
    
    /**
     * Verifica si la conexión a la base de datos está disponible
     * 
     * @return true si la conexión está disponible, false en caso contrario
     */
    public static boolean testConnection() {
        Connection conn = null;
        try {
            conn = getConnection();
            return conn != null && !conn.isClosed();
        } catch (SQLException e) {
            LOGGER.log(Level.WARNING, "Error al probar la conexión", e);
            return false;
        } finally {
            closeConnection(conn);
        }
    }
    
    /**
     * Ejecuta una transacción con manejo automático de commit/rollback
     * 
     * @param transaction la transacción a ejecutar
     * @return true si la transacción fue exitosa, false en caso contrario
     */
    public static boolean executeTransaction(DatabaseTransaction transaction) {
        Connection conn = null;
        try {
            conn = getConnection();
            conn.setAutoCommit(false);
            
            boolean result = transaction.execute(conn);
            
            if (result) {
                conn.commit();
                LOGGER.fine("Transacción completada exitosamente");
            } else {
                conn.rollback();
                LOGGER.warning("Transacción revertida");
            }
            
            return result;
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Error en la transacción", e);
            if (conn != null) {
                try {
                    conn.rollback();
                    LOGGER.info("Rollback ejecutado debido a error");
                } catch (SQLException ex) {
                    LOGGER.log(Level.SEVERE, "Error al hacer rollback", ex);
                }
            }
            return false;
        } finally {
            if (conn != null) {
                try {
                    conn.setAutoCommit(true);
                } catch (SQLException e) {
                    LOGGER.log(Level.WARNING, "Error al restaurar autoCommit", e);
                }
            }
            closeConnection(conn);
        }
    }
    
    /**
     * Interfaz funcional para ejecutar transacciones
     */
    @FunctionalInterface
    public interface DatabaseTransaction {
        boolean execute(Connection conn) throws SQLException;
    }
}

// Made with Bob