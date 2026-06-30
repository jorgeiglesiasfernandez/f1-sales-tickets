<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib prefix="s" uri="/struts-tags" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - F1 España 2026</title>
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
            padding: 30px 20px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
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
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .stat-card {
            background: #fff;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            border-left: 5px solid #e60000;
            transition: transform 0.3s;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 20px rgba(0, 0, 0, 0.15);
        }
        
        .stat-card.success {
            border-left-color: #4caf50;
        }
        
        .stat-card.warning {
            border-left-color: #ff9800;
        }
        
        .stat-card.info {
            border-left-color: #2196f3;
        }
        
        .stat-card .icon {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .stat-card .label {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .stat-card .value {
            font-size: 2.5em;
            font-weight: bold;
            color: #333;
        }
        
        .stat-card .subvalue {
            color: #999;
            font-size: 0.9em;
            margin-top: 5px;
        }
        
        .progress-section {
            background: #fff;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            margin-bottom: 30px;
        }
        
        .progress-section h2 {
            color: #e60000;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        
        .progress-bar-container {
            background: #f0f0f0;
            height: 40px;
            border-radius: 20px;
            overflow: hidden;
            margin-bottom: 15px;
            position: relative;
        }
        
        .progress-bar {
            height: 100%;
            background: linear-gradient(90deg, #4caf50 0%, #8bc34a 100%);
            transition: width 1s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            font-weight: bold;
        }
        
        .progress-bar.warning {
            background: linear-gradient(90deg, #ff9800 0%, #ffc107 100%);
        }
        
        .progress-bar.danger {
            background: linear-gradient(90deg, #f44336 0%, #e91e63 100%);
        }
        
        .availability-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-top: 20px;
        }
        
        .availability-card {
            background: #f8f8f8;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        
        .availability-card h3 {
            margin-bottom: 15px;
            color: #333;
        }
        
        .availability-card .count {
            font-size: 3em;
            font-weight: bold;
            color: #e60000;
        }
        
        .recent-purchases {
            background: #fff;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            margin-bottom: 30px;
        }
        
        .recent-purchases h2 {
            color: #e60000;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        
        .purchase-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .purchase-table th {
            background: #f5f5f5;
            padding: 15px;
            text-align: left;
            font-weight: bold;
            color: #666;
            border-bottom: 2px solid #e60000;
        }
        
        .purchase-table td {
            padding: 15px;
            border-bottom: 1px solid #eee;
        }
        
        .purchase-table tr:hover {
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
        
        .badge.confirmed {
            background: #e8f5e9;
            color: #388e3c;
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
        
        .event-info-box {
            background: linear-gradient(135deg, #e60000 0%, #1a1a1a 100%);
            color: #fff;
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        
        .event-info-box h2 {
            color: #ffcc00;
            margin-bottom: 15px;
        }
        
        .event-info-box p {
            margin: 8px 0;
            font-size: 1.1em;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <h1>📊 Dashboard de Ventas</h1>
            <p class="subtitle">Gran Premio de España 2026</p>
        </div>
    </div>
    
    <div class="container">
        <div class="event-info-box">
            <h2>🏁 <s:property value="event.nombre"/></h2>
            <p>📍 <s:property value="event.circuito"/> - <s:property value="event.ubicacion"/></p>
            <p>📅 <s:date name="event.fecha" format="dd/MM/yyyy HH:mm"/></p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card success">
                <div class="icon">🎫</div>
                <div class="label">Entradas Vendidas</div>
                <div class="value"><s:property value="entradasVendidas"/></div>
                <div class="subvalue">de 1000 totales</div>
            </div>
            
            <div class="stat-card warning">
                <div class="icon">📦</div>
                <div class="label">Entradas Disponibles</div>
                <div class="value"><s:property value="entradasDisponibles"/></div>
                <div class="subvalue"><s:property value="getText('{0,number,#.##}%', {porcentajeVendido})"/> vendido</div>
            </div>
            
            <div class="stat-card info">
                <div class="icon">💰</div>
                <div class="label">Ingresos Totales</div>
                <div class="value">€<s:property value="ingresosTotales"/></div>
                <div class="subvalue"><s:property value="totalCompras"/> compras</div>
            </div>
            
            <div class="stat-card">
                <div class="icon">📈</div>
                <div class="label">Promedio por Compra</div>
                <div class="value"><s:property value="getText('{0,number,#.##}', {promedioEntradasPorCompra})"/></div>
                <div class="subvalue">entradas/compra</div>
            </div>
        </div>
        
        <div class="progress-section">
            <h2>📊 Progreso de Ventas</h2>
            <div class="progress-bar-container">
                <div class="progress-bar <s:if test='porcentajeVendido >= 80'>danger</s:if><s:elseif test='porcentajeVendido >= 50'>warning</s:elseif>" 
                     style="width: <s:property value='porcentajeVendido'/>%">
                    <s:property value="getText('{0,number,#.##}%', {porcentajeVendido})"/>
                </div>
            </div>
            
            <div class="availability-grid">
                <div class="availability-card">
                    <h3>🎟️ Entradas General</h3>
                    <div class="count"><s:property value="generalDisponibles"/></div>
                    <p>disponibles de 700</p>
                </div>
                <div class="availability-card">
                    <h3>⭐ Entradas VIP</h3>
                    <div class="count"><s:property value="vipDisponibles"/></div>
                    <p>disponibles de 300</p>
                </div>
            </div>
        </div>
        
        <div class="recent-purchases">
            <h2>🛒 Compras Recientes</h2>
            <s:if test="comprasRecientes != null && !comprasRecientes.isEmpty()">
                <table class="purchase-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Cliente</th>
                            <th>Email</th>
                            <th>Tipo</th>
                            <th>Cantidad</th>
                            <th>Total</th>
                            <th>Fecha</th>
                            <th>Estado</th>
                        </tr>
                    </thead>
                    <tbody>
                        <s:iterator value="comprasRecientes" var="compra">
                            <tr>
                                <td><strong><s:property value="id"/></strong></td>
                                <td><s:property value="nombreComprador"/></td>
                                <td><s:property value="email"/></td>
                                <td>
                                    <span class="badge <s:if test='tipoEntrada.name() == "GENERAL"'>general</s:if><s:else>vip</s:else>">
                                        <s:property value="tipoEntrada.descripcion"/>
                                    </span>
                                </td>
                                <td><s:property value="cantidadEntradas"/></td>
                                <td><strong>€<s:property value="precioTotal"/></strong></td>
                                <td><s:date name="fechaCompra" format="dd/MM/yyyy HH:mm"/></td>
                                <td><span class="badge confirmed"><s:property value="estado"/></span></td>
                            </tr>
                        </s:iterator>
                    </tbody>
                </table>
            </s:if>
            <s:else>
                <p style="text-align: center; color: #999; padding: 40px;">
                    No hay compras registradas todavía
                </p>
            </s:else>
        </div>
        
        <div class="actions">
            <a href="<s:url action='purchase-list'/>" class="btn btn-primary">📋 Ver Todas las Compras</a>
            <a href="<s:url action='ticket-list'/>" class="btn btn-secondary">🎫 Ver Entradas</a>
            <a href="<s:url action='event-info'/>" class="btn btn-secondary">ℹ️ Info del Evento</a>
            <a href="<s:url value='/'/>" class="btn btn-secondary">🏠 Inicio</a>
        </div>
    </div>
</body>
</html>