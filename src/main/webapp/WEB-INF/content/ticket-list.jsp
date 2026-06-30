<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib prefix="s" uri="/struts-tags" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Entradas Disponibles - F1 España 2026</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Arial', sans-serif;
            background: #f5f5f5;
            color: #333;
        }
        
        .header {
            background: linear-gradient(135deg, #e60000 0%, #1a1a1a 100%);
            color: #fff;
            padding: 40px 20px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .header .subtitle {
            font-size: 1.2em;
            color: #ffcc00;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 30px 20px;
        }
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .summary-card {
            background: #fff;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            text-align: center;
            border-top: 5px solid #e60000;
        }
        
        .summary-card.general {
            border-top-color: #2196f3;
        }
        
        .summary-card.vip {
            border-top-color: #ff9800;
        }
        
        .summary-card .icon {
            font-size: 3em;
            margin-bottom: 10px;
        }
        
        .summary-card .label {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 10px;
        }
        
        .summary-card .value {
            font-size: 2.5em;
            font-weight: bold;
            color: #e60000;
        }
        
        .summary-card .price {
            font-size: 1.2em;
            color: #666;
            margin-top: 10px;
        }
        
        .filters {
            background: #fff;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }
        
        .filters h3 {
            color: #e60000;
            margin-bottom: 15px;
        }
        
        .filter-buttons {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        .filter-btn {
            padding: 10px 25px;
            border: 2px solid #e60000;
            background: #fff;
            color: #e60000;
            border-radius: 5px;
            cursor: pointer;
            font-weight: bold;
            transition: all 0.3s;
            text-decoration: none;
            display: inline-block;
        }
        
        .filter-btn:hover,
        .filter-btn.active {
            background: #e60000;
            color: #fff;
        }
        
        .tickets-section {
            background: #fff;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            margin-bottom: 30px;
        }
        
        .tickets-section h2 {
            color: #e60000;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        
        .tickets-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        
        .tickets-table thead {
            background: #f5f5f5;
        }
        
        .tickets-table th {
            padding: 15px;
            text-align: left;
            font-weight: bold;
            color: #666;
            border-bottom: 2px solid #e60000;
        }
        
        .tickets-table td {
            padding: 15px;
            border-bottom: 1px solid #eee;
        }
        
        .tickets-table tr:hover {
            background: #f9f9f9;
        }
        
        .badge {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: bold;
        }
        
        .badge.general {
            background: #e3f2fd;
            color: #1976d2;
        }
        
        .badge.vip {
            background: #fff3e0;
            color: #f57c00;
        }
        
        .badge.available {
            background: #e8f5e9;
            color: #388e3c;
        }
        
        .badge.sold {
            background: #ffebee;
            color: #c62828;
        }
        
        .seat-number {
            font-family: 'Courier New', monospace;
            font-weight: bold;
            color: #e60000;
        }
        
        .btn {
            display: inline-block;
            padding: 12px 30px;
            margin: 10px 5px;
            text-decoration: none;
            border-radius: 5px;
            transition: all 0.3s;
            font-weight: bold;
        }
        
        .btn-primary {
            background: #e60000;
            color: #fff;
        }
        
        .btn-primary:hover {
            background: #ff1a1a;
            transform: scale(1.05);
        }
        
        .btn-secondary {
            background: #666;
            color: #fff;
        }
        
        .btn-secondary:hover {
            background: #777;
        }
        
        .actions {
            text-align: center;
            margin-top: 30px;
        }
        
        .info-message {
            background: #e3f2fd;
            color: #1976d2;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            border-left: 4px solid #1976d2;
        }
        
        .pagination {
            text-align: center;
            margin-top: 20px;
        }
        
        .pagination-info {
            color: #666;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎫 Entradas Disponibles</h1>
        <p class="subtitle"><s:property value="event.nombre"/></p>
        <p style="margin-top: 10px;"><s:date name="event.fecha" format="dd/MM/yyyy HH:mm"/></p>
    </div>
    
    <div class="container">
        <div class="summary-cards">
            <div class="summary-card">
                <div class="icon">🎟️</div>
                <div class="label">Total Disponibles</div>
                <div class="value"><s:property value="totalAvailable"/></div>
                <div class="price">de 1000 entradas</div>
            </div>
            
            <div class="summary-card general">
                <div class="icon">🎫</div>
                <div class="label">Entradas General</div>
                <div class="value"><s:property value="generalAvailable"/></div>
                <div class="price">€150.00 c/u</div>
            </div>
            
            <div class="summary-card vip">
                <div class="icon">⭐</div>
                <div class="label">Entradas VIP</div>
                <div class="value"><s:property value="vipAvailable"/></div>
                <div class="price">€450.00 c/u</div>
            </div>
        </div>
        
        <div class="info-message">
            <strong>ℹ️ Información:</strong> Mostrando las primeras 50 entradas disponibles. 
            Todas las entradas incluyen asiento numerado asignado automáticamente al momento de la compra.
        </div>
        
        <div class="filters">
            <h3>🔍 Filtrar por Tipo</h3>
            <div class="filter-buttons">
                <a href="<s:url action='ticket-list'/>" class="filter-btn <s:if test='tipoFiltro == null || tipoFiltro.isEmpty()'>active</s:if>">
                    Todas
                </a>
                <a href="<s:url action='ticket-list'><s:param name='tipoFiltro' value='"GENERAL"'/></s:url>" 
                   class="filter-btn <s:if test='tipoFiltro == "GENERAL"'>active</s:if>">
                    🎫 General
                </a>
                <a href="<s:url action='ticket-list'><s:param name='tipoFiltro' value='"VIP"'/></s:url>" 
                   class="filter-btn <s:if test='tipoFiltro == "VIP"'>active</s:if>">
                    ⭐ VIP
                </a>
            </div>
        </div>
        
        <div class="tickets-section">
            <h2>📋 Listado de Entradas</h2>
            
            <s:if test="availableTickets != null && !availableTickets.isEmpty()">
                <table class="tickets-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Tipo</th>
                            <th>Sección</th>
                            <th>Asiento</th>
                            <th>Precio</th>
                            <th>Estado</th>
                        </tr>
                    </thead>
                    <tbody>
                        <s:iterator value="availableTickets" var="ticket" status="status">
                            <s:if test="#status.index < 50">
                                <tr>
                                    <td><strong><s:property value="id"/></strong></td>
                                    <td>
                                        <span class="badge <s:if test='tipo.name() == "GENERAL"'>general</s:if><s:else>vip</s:else>">
                                            <s:property value="tipo.descripcion"/>
                                        </span>
                                    </td>
                                    <td><strong><s:property value="seccion"/></strong></td>
                                    <td><span class="seat-number"><s:property value="asiento"/></span></td>
                                    <td><strong>€<s:property value="precio"/></strong></td>
                                    <td>
                                        <span class="badge <s:if test='disponible'>available</s:if><s:else>sold</s:else>">
                                            <s:if test="disponible">Disponible</s:if>
                                            <s:else>Vendida</s:else>
                                        </span>
                                    </td>
                                </tr>
                            </s:if>
                        </s:iterator>
                    </tbody>
                </table>
                
                <div class="pagination">
                    <p class="pagination-info">
                        Mostrando <strong>50</strong> de <strong><s:property value="availableTickets.size()"/></strong> entradas disponibles
                    </p>
                </div>
            </s:if>
            <s:else>
                <p style="text-align: center; color: #999; padding: 40px;">
                    😔 No hay entradas disponibles en este momento
                </p>
            </s:else>
        </div>
        
        <div class="actions">
            <a href="<s:url action='purchase-form'/>" class="btn btn-primary">🛒 Comprar Entradas</a>
            <a href="<s:url action='event-info'/>" class="btn btn-secondary">ℹ️ Info del Evento</a>
            <a href="<s:url action='dashboard'/>" class="btn btn-secondary">📊 Dashboard</a>
            <a href="<s:url value='/'/>" class="btn btn-secondary">🏠 Inicio</a>
        </div>
    </div>
</body>
</html>