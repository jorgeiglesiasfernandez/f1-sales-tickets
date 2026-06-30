<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib prefix="s" uri="/struts-tags" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Información del Evento - F1 España 2026</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Arial', sans-serif;
            background: linear-gradient(135deg, #e60000 0%, #1a1a1a 100%);
            color: #fff;
            min-height: 100vh;
        }
        
        .hero {
            text-align: center;
            padding: 60px 20px;
            background: rgba(0, 0, 0, 0.6);
        }
        
        .hero h1 {
            font-size: 3em;
            margin-bottom: 20px;
            color: #ffcc00;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        .info-section {
            background: rgba(255, 255, 255, 0.95);
            color: #333;
            padding: 40px;
            border-radius: 15px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
        }
        
        .info-section h2 {
            color: #e60000;
            margin-bottom: 20px;
            font-size: 2em;
            border-bottom: 3px solid #e60000;
            padding-bottom: 10px;
        }
        
        .info-section p {
            line-height: 1.8;
            margin-bottom: 15px;
            font-size: 1.1em;
        }
        
        .details-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        
        .detail-card {
            background: #f8f8f8;
            padding: 25px;
            border-radius: 10px;
            border-left: 5px solid #e60000;
        }
        
        .detail-card h3 {
            color: #e60000;
            margin-bottom: 15px;
            font-size: 1.3em;
        }
        
        .detail-card .icon {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .detail-card p {
            color: #666;
            line-height: 1.6;
        }
        
        .availability-banner {
            background: linear-gradient(135deg, #4caf50 0%, #8bc34a 100%);
            color: #fff;
            padding: 30px;
            border-radius: 15px;
            text-align: center;
            margin-bottom: 30px;
        }
        
        .availability-banner h2 {
            font-size: 2em;
            margin-bottom: 15px;
        }
        
        .availability-banner .stats {
            display: flex;
            justify-content: center;
            gap: 50px;
            margin-top: 20px;
        }
        
        .availability-banner .stat {
            text-align: center;
        }
        
        .availability-banner .stat .number {
            font-size: 3em;
            font-weight: bold;
        }
        
        .availability-banner .stat .label {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .circuit-info {
            background: rgba(255, 255, 255, 0.95);
            color: #333;
            padding: 40px;
            border-radius: 15px;
            margin-bottom: 30px;
        }
        
        .circuit-info h2 {
            color: #e60000;
            margin-bottom: 20px;
            font-size: 2em;
        }
        
        .circuit-features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        
        .feature {
            text-align: center;
            padding: 20px;
            background: #f8f8f8;
            border-radius: 10px;
        }
        
        .feature .icon {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .feature .value {
            font-size: 1.8em;
            font-weight: bold;
            color: #e60000;
            margin-bottom: 5px;
        }
        
        .feature .label {
            color: #666;
        }
        
        .ticket-types {
            background: rgba(255, 255, 255, 0.95);
            color: #333;
            padding: 40px;
            border-radius: 15px;
            margin-bottom: 30px;
        }
        
        .ticket-types h2 {
            color: #e60000;
            margin-bottom: 30px;
            font-size: 2em;
        }
        
        .ticket-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 30px;
        }
        
        .ticket-card {
            background: #fff;
            border: 3px solid #ddd;
            border-radius: 15px;
            padding: 30px;
            transition: transform 0.3s;
        }
        
        .ticket-card:hover {
            transform: translateY(-10px);
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }
        
        .ticket-card.general {
            border-color: #2196f3;
        }
        
        .ticket-card.vip {
            border-color: #ff9800;
            background: linear-gradient(135deg, #fff9e6 0%, #fff 100%);
        }
        
        .ticket-card h3 {
            font-size: 2em;
            margin-bottom: 15px;
        }
        
        .ticket-card .price {
            font-size: 3em;
            font-weight: bold;
            color: #e60000;
            margin-bottom: 20px;
        }
        
        .ticket-card ul {
            list-style: none;
            margin-bottom: 20px;
        }
        
        .ticket-card ul li {
            padding: 10px 0;
            border-bottom: 1px solid #eee;
        }
        
        .ticket-card ul li:before {
            content: "✓ ";
            color: #4caf50;
            font-weight: bold;
            margin-right: 10px;
        }
        
        .btn {
            display: inline-block;
            padding: 15px 40px;
            margin: 10px 5px;
            font-size: 1.1em;
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
            margin-top: 40px;
        }
    </style>
</head>
<body>
    <div class="hero">
        <h1>🏁 <s:property value="event.nombre"/></h1>
        <p style="font-size: 1.5em; margin-top: 10px;">
            <s:date name="event.fecha" format="dd 'de' MMMM 'de' yyyy"/>
        </p>
    </div>
    
    <div class="container">
        <div class="availability-banner">
            <h2>🎫 Disponibilidad de Entradas</h2>
            <div class="stats">
                <div class="stat">
                    <div class="number"><s:property value="entradasDisponibles"/></div>
                    <div class="label">Entradas Disponibles</div>
                </div>
                <div class="stat">
                    <div class="number"><s:property value="entradasVendidas"/></div>
                    <div class="label">Entradas Vendidas</div>
                </div>
                <div class="stat">
                    <div class="number"><s:property value="getText('{0,number,#.#}%', {porcentajeVendido})"/></div>
                    <div class="label">Ocupación</div>
                </div>
            </div>
        </div>
        
        <div class="info-section">
            <h2>📍 Información del Evento</h2>
            <p><strong>Circuito:</strong> <s:property value="event.circuito"/></p>
            <p><strong>Ubicación:</strong> <s:property value="event.ubicacion"/></p>
            <p><strong>Fecha y Hora:</strong> <s:date name="event.fecha" format="EEEE, dd 'de' MMMM 'de' yyyy 'a las' HH:mm 'horas'"/></p>
            <p><s:property value="event.descripcion"/></p>
            
            <div class="details-grid">
                <div class="detail-card">
                    <div class="icon">🏎️</div>
                    <h3>Experiencia Única</h3>
                    <p>Vive la emoción de la Fórmula 1 en uno de los circuitos más emblemáticos de Europa. Velocidad, adrenalina y espectáculo garantizados.</p>
                </div>
                
                <div class="detail-card">
                    <div class="icon">🎯</div>
                    <h3>Ubicación Privilegiada</h3>
                    <p>El Circuit de Barcelona-Catalunya ofrece excelentes vistas desde todas las zonas, permitiéndote disfrutar de cada momento de la carrera.</p>
                </div>
                
                <div class="detail-card">
                    <div class="icon">🎉</div>
                    <h3>Ambiente Festivo</h3>
                    <p>Disfruta de un ambiente único con miles de aficionados de todo el mundo celebrando la pasión por el automovilismo.</p>
                </div>
            </div>
        </div>
        
        <div class="circuit-info">
            <h2>🏁 Datos del Circuito</h2>
            <div class="circuit-features">
                <div class="feature">
                    <div class="icon">📏</div>
                    <div class="value">4.675</div>
                    <div class="label">km de longitud</div>
                </div>
                <div class="feature">
                    <div class="icon">🔄</div>
                    <div class="value">16</div>
                    <div class="label">curvas</div>
                </div>
                <div class="feature">
                    <div class="icon">🏎️</div>
                    <div class="value">66</div>
                    <div class="label">vueltas</div>
                </div>
                <div class="feature">
                    <div class="icon">⚡</div>
                    <div class="value">312</div>
                    <div class="label">km/h velocidad máx.</div>
                </div>
            </div>
        </div>
        
        <div class="ticket-types">
            <h2>🎫 Tipos de Entradas</h2>
            <div class="ticket-grid">
                <div class="ticket-card general">
                    <h3>🎟️ Entrada General</h3>
                    <div class="price">€150</div>
                    <ul>
                        <li>Acceso a gradas principales</li>
                        <li>Vista completa del circuito</li>
                        <li>Asiento numerado</li>
                        <li>Acceso a zonas comunes</li>
                        <li>Pantallas gigantes</li>
                        <li><strong><s:property value="generalDisponibles"/> disponibles</strong></li>
                    </ul>
                </div>
                
                <div class="ticket-card vip">
                    <h3>⭐ Entrada VIP</h3>
                    <div class="price">€450</div>
                    <ul>
                        <li>Acceso a zona VIP premium</li>
                        <li>Mejores vistas del circuito</li>
                        <li>Asiento premium numerado</li>
                        <li>Acceso a hospitality lounge</li>
                        <li>Servicio de catering incluido</li>
                        <li>Parking reservado</li>
                        <li>Merchandising exclusivo</li>
                        <li><strong><s:property value="vipDisponibles"/> disponibles</strong></li>
                    </ul>
                </div>
            </div>
        </div>
        
        <div class="actions">
            <a href="<s:url action='purchase-form'/>" class="btn btn-primary">🛒 Comprar Entradas</a>
            <a href="<s:url action='ticket-list'/>" class="btn btn-secondary">📋 Ver Disponibilidad</a>
            <a href="<s:url action='dashboard'/>" class="btn btn-secondary">📊 Dashboard</a>
            <a href="<s:url value='/'/>" class="btn btn-secondary">🏠 Inicio</a>
        </div>
    </div>
</body>
</html>