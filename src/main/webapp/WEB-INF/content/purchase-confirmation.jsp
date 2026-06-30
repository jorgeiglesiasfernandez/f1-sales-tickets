<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib prefix="s" uri="/struts-tags" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Compra Confirmada - F1 España 2026</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Arial', sans-serif;
            background: linear-gradient(135deg, #4caf50 0%, #1b5e20 100%);
            color: #333;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 900px;
            margin: 0 auto;
            background: #fff;
            border-radius: 15px;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
        }
        
        .success-header {
            text-align: center;
            margin-bottom: 40px;
        }
        
        .success-icon {
            font-size: 5em;
            color: #4caf50;
            margin-bottom: 20px;
        }
        
        h1 {
            color: #4caf50;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .confirmation-code {
            background: #f8f8f8;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            margin-bottom: 30px;
            border: 2px dashed #4caf50;
        }
        
        .confirmation-code h2 {
            color: #333;
            margin-bottom: 10px;
            font-size: 1.2em;
        }
        
        .confirmation-code .code {
            font-size: 2em;
            font-weight: bold;
            color: #4caf50;
            letter-spacing: 2px;
        }
        
        .purchase-details {
            background: #f8f8f8;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        
        .purchase-details h2 {
            color: #e60000;
            margin-bottom: 20px;
            border-bottom: 2px solid #e60000;
            padding-bottom: 10px;
        }
        
        .detail-row {
            display: flex;
            justify-content: space-between;
            padding: 12px 0;
            border-bottom: 1px solid #ddd;
        }
        
        .detail-row:last-child {
            border-bottom: none;
        }
        
        .detail-label {
            font-weight: bold;
            color: #666;
        }
        
        .detail-value {
            color: #333;
            text-align: right;
        }
        
        .seats-section {
            background: #fff3e0;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 30px;
            border-left: 4px solid #ff9800;
        }
        
        .seats-section h3 {
            color: #ff9800;
            margin-bottom: 15px;
        }
        
        .seats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
            gap: 10px;
        }
        
        .seat-badge {
            background: #fff;
            padding: 10px;
            border-radius: 5px;
            text-align: center;
            font-weight: bold;
            border: 2px solid #ff9800;
            color: #ff9800;
        }
        
        .price-summary {
            background: #e3f2fd;
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        
        .price-summary h3 {
            color: #1976d2;
            margin-bottom: 15px;
        }
        
        .price-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            padding-bottom: 10px;
            border-bottom: 1px solid #90caf9;
        }
        
        .price-row.total {
            font-size: 1.5em;
            font-weight: bold;
            border-bottom: none;
            margin-top: 10px;
            color: #1976d2;
        }
        
        .event-reminder {
            background: #ffebee;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 30px;
            border-left: 4px solid #e60000;
        }
        
        .event-reminder h3 {
            color: #e60000;
            margin-bottom: 10px;
        }
        
        .event-reminder p {
            color: #666;
            line-height: 1.6;
        }
        
        .btn {
            display: inline-block;
            padding: 15px 40px;
            margin: 10px 5px;
            font-size: 1.1em;
            text-decoration: none;
            border-radius: 5px;
            border: none;
            cursor: pointer;
            transition: all 0.3s;
            font-weight: bold;
        }
        
        .btn-primary {
            background: #4caf50;
            color: #fff;
        }
        
        .btn-primary:hover {
            background: #66bb6a;
            transform: scale(1.05);
        }
        
        .btn-secondary {
            background: #e60000;
            color: #fff;
        }
        
        .btn-secondary:hover {
            background: #ff1a1a;
        }
        
        .button-group {
            text-align: center;
            margin-top: 30px;
        }
        
        .info-box {
            background: #fff9c4;
            padding: 15px;
            border-radius: 5px;
            margin-top: 20px;
            border-left: 4px solid #fbc02d;
        }
        
        .info-box p {
            color: #666;
            margin: 5px 0;
        }
        
        @media print {
            body {
                background: #fff;
            }
            .button-group {
                display: none;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success-header">
            <div class="success-icon">✅</div>
            <h1>¡Compra Confirmada!</h1>
            <p style="font-size: 1.2em; color: #666;">Tu compra se ha procesado correctamente</p>
        </div>
        
        <div class="confirmation-code">
            <h2>Código de Confirmación</h2>
            <div class="code"><s:property value="purchase.codigoConfirmacion"/></div>
            <p style="margin-top: 10px; color: #666;">Guarda este código para futuras referencias</p>
        </div>
        
        <div class="purchase-details">
            <h2>📋 Detalles de la Compra</h2>
            <div class="detail-row">
                <span class="detail-label">ID de Compra:</span>
                <span class="detail-value"><s:property value="purchase.id"/></span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Nombre:</span>
                <span class="detail-value"><s:property value="purchase.nombreComprador"/></span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Email:</span>
                <span class="detail-value"><s:property value="purchase.email"/></span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Teléfono:</span>
                <span class="detail-value"><s:property value="purchase.telefono"/></span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Fecha de Compra:</span>
                <span class="detail-value"><s:date name="purchase.fechaCompra" format="dd/MM/yyyy HH:mm:ss"/></span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Tipo de Entrada:</span>
                <span class="detail-value"><s:property value="purchase.tipoEntrada.descripcion"/></span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Cantidad:</span>
                <span class="detail-value"><s:property value="purchase.cantidadEntradas"/> entrada(s)</span>
            </div>
        </div>
        
        <div class="seats-section">
            <h3>🪑 Asientos Asignados</h3>
            <div class="seats-grid">
                <s:iterator value="purchase.asientosAsignados" var="asiento">
                    <div class="seat-badge"><s:property value="asiento"/></div>
                </s:iterator>
            </div>
        </div>
        
        <div class="price-summary">
            <h3>💰 Resumen del Pago</h3>
            <div class="price-row">
                <span>Precio por entrada:</span>
                <span>€<s:property value="purchase.tipoEntrada.precio"/></span>
            </div>
            <div class="price-row">
                <span>Cantidad de entradas:</span>
                <span><s:property value="purchase.cantidadEntradas"/></span>
            </div>
            <div class="price-row total">
                <span>TOTAL PAGADO:</span>
                <span>€<s:property value="purchase.precioTotal"/></span>
            </div>
        </div>
        
        <div class="event-reminder">
            <h3>🏁 Información del Evento</h3>
            <p><strong>Evento:</strong> <s:property value="event.nombre"/></p>
            <p><strong>Fecha:</strong> <s:date name="event.fecha" format="dd/MM/yyyy HH:mm"/></p>
            <p><strong>Lugar:</strong> <s:property value="event.circuito"/> - <s:property value="event.ubicacion"/></p>
            <p style="margin-top: 15px;">
                <strong>⚠️ Importante:</strong> Presenta tu código de confirmación y un documento de identidad 
                en la entrada del circuito. Te recomendamos llegar con al menos 2 horas de antelación.
            </p>
        </div>
        
        <div class="info-box">
            <p><strong>📧 Confirmación por Email:</strong> Hemos enviado un email de confirmación a <strong><s:property value="purchase.email"/></strong> con todos los detalles de tu compra.</p>
            <p><strong>🎫 Entradas Restantes:</strong> Quedan <strong><s:property value="event.entradasDisponibles"/></strong> entradas disponibles para este evento.</p>
        </div>
        
        <div class="button-group">
            <button onclick="window.print()" class="btn btn-primary">🖨️ Imprimir Confirmación</button>
            <a href="${pageContext.request.contextPath}/" class="btn btn-secondary">🏠 Volver al Inicio</a>
            <a href="<s:url action='purchase-form'/>" class="btn btn-secondary">🎫 Comprar Más Entradas</a>
        </div>
    </div>
</body>
</html>