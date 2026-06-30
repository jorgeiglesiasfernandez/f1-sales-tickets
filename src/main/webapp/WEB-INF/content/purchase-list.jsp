<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib prefix="s" uri="/struts-tags" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lista de Compras - F1 España 2026</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Arial', sans-serif;
            background: linear-gradient(135deg, #e60000 0%, #1a1a1a 100%);
            color: #333;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: #fff;
            border-radius: 15px;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding-bottom: 20px;
            border-bottom: 3px solid #e60000;
        }
        
        h1 {
            color: #e60000;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .subtitle {
            color: #666;
            font-size: 1.2em;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #e60000 0%, #c50000 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        
        .stat-value {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .stat-label {
            font-size: 1em;
            opacity: 0.9;
        }
        
        .table-container {
            overflow-x: auto;
            margin-top: 30px;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
        }
        
        thead {
            background: #e60000;
            color: white;
        }
        
        th {
            padding: 15px;
            text-align: left;
            font-weight: bold;
            font-size: 1em;
        }
        
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #ddd;
        }
        
        tbody tr:hover {
            background: #f5f5f5;
        }
        
        .status-badge {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: bold;
        }
        
        .status-confirmada {
            background: #4caf50;
            color: white;
        }
        
        .status-pendiente {
            background: #ff9800;
            color: white;
        }
        
        .status-cancelada {
            background: #f44336;
            color: white;
        }
        
        .ticket-type {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 5px;
            font-weight: bold;
        }
        
        .type-general {
            background: #2196f3;
            color: white;
        }
        
        .type-vip {
            background: #ffd700;
            color: #333;
        }
        
        .no-purchases {
            text-align: center;
            padding: 60px 20px;
            color: #666;
        }
        
        .no-purchases-icon {
            font-size: 5em;
            margin-bottom: 20px;
            opacity: 0.3;
        }
        
        .actions {
            text-align: center;
            margin-top: 30px;
        }
        
        .btn {
            display: inline-block;
            padding: 15px 40px;
            background: #e60000;
            color: white;
            text-decoration: none;
            border-radius: 30px;
            font-size: 1.1em;
            font-weight: bold;
            transition: all 0.3s;
            border: none;
            cursor: pointer;
            margin: 5px;
        }
        
        .btn:hover {
            background: #c50000;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(230, 0, 0, 0.3);
        }
        
        .btn-secondary {
            background: #666;
        }
        
        .btn-secondary:hover {
            background: #555;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 20px;
            }
            
            h1 {
                font-size: 2em;
            }
            
            table {
                font-size: 0.9em;
            }
            
            th, td {
                padding: 8px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📋 Lista de Compras</h1>
            <p class="subtitle">Gran Premio de España 2026</p>
        </div>
        
        <s:if test="recentPurchases != null && !recentPurchases.isEmpty()">
            <div class="stats">
                <div class="stat-card">
                    <div class="stat-value"><s:property value="recentPurchases.size()"/></div>
                    <div class="stat-label">Compras Totales</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">
                        <s:set var="totalTickets" value="0"/>
                        <s:iterator value="recentPurchases" var="p">
                            <s:set var="totalTickets" value="#totalTickets + #p.cantidadEntradas"/>
                        </s:iterator>
                        <s:property value="#totalTickets"/>
                    </div>
                    <div class="stat-label">Entradas Vendidas</div>
                </div>
            </div>
            
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>ID Compra</th>
                            <th>Comprador</th>
                            <th>Email</th>
                            <th>Teléfono</th>
                            <th>Tipo</th>
                            <th>Cantidad</th>
                            <th>Precio Total</th>
                            <th>Estado</th>
                            <th>Fecha</th>
                        </tr>
                    </thead>
                    <tbody>
                        <s:iterator value="recentPurchases" var="purchase">
                            <tr>
                                <td><strong><s:property value="#purchase.id"/></strong></td>
                                <td><s:property value="#purchase.nombreComprador"/></td>
                                <td><s:property value="#purchase.email"/></td>
                                <td><s:property value="#purchase.telefono"/></td>
                                <td>
                                    <span class="ticket-type type-<s:property value='#purchase.tipoEntrada.name().toLowerCase()'/>">
                                        <s:property value="#purchase.tipoEntrada.descripcion"/>
                                    </span>
                                </td>
                                <td><strong><s:property value="#purchase.cantidadEntradas"/></strong></td>
                                <td><strong><s:property value="#purchase.precioTotal"/>€</strong></td>
                                <td>
                                    <span class="status-badge status-<s:property value='#purchase.estado.name().toLowerCase()'/>">
                                        <s:property value="#purchase.estado.name()"/>
                                    </span>
                                </td>
                                <td><s:date name="#purchase.fechaCompra" format="dd/MM/yyyy HH:mm"/></td>
                            </tr>
                        </s:iterator>
                    </tbody>
                </table>
            </div>
        </s:if>
        <s:else>
            <div class="no-purchases">
                <div class="no-purchases-icon">🎫</div>
                <h2>No hay compras registradas</h2>
                <p>Aún no se han realizado compras para este evento.</p>
            </div>
        </s:else>
        
        <div class="actions">
            <a href="<s:url action='dashboard'/>" class="btn btn-secondary">🏠 Volver al Dashboard</a>
            <a href="<s:url action='purchase-form'/>" class="btn">🎫 Nueva Compra</a>
        </div>
    </div>
</body>
</html>

<!-- Made with Bob -->