<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib prefix="s" uri="/struts-tags" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Comprar Entradas - F1 España 2026</title>
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
            max-width: 800px;
            margin: 0 auto;
            background: #fff;
            border-radius: 15px;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
        }
        
        h1 {
            color: #e60000;
            text-align: center;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        
        .event-info {
            text-align: center;
            padding: 20px;
            background: #f8f8f8;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        
        .event-info h2 {
            color: #333;
            margin-bottom: 10px;
        }
        
        .event-info p {
            color: #666;
            margin: 5px 0;
        }
        
        .availability {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .availability-card {
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            border: 2px solid #ddd;
        }
        
        .availability-card.general {
            background: #e3f2fd;
            border-color: #2196f3;
        }
        
        .availability-card.vip {
            background: #fff3e0;
            border-color: #ff9800;
        }
        
        .availability-card h3 {
            margin-bottom: 10px;
        }
        
        .availability-card .count {
            font-size: 2em;
            font-weight: bold;
            color: #e60000;
        }
        
        .form-group {
            margin-bottom: 25px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: bold;
            color: #333;
        }
        
        input[type="text"],
        input[type="email"],
        input[type="tel"],
        input[type="number"],
        select {
            width: 100%;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 5px;
            font-size: 1em;
            transition: border-color 0.3s;
        }
        
        input:focus,
        select:focus {
            outline: none;
            border-color: #e60000;
        }
        
        .error {
            color: #e60000;
            font-size: 0.9em;
            margin-top: 5px;
        }
        
        .error-message {
            background: #ffebee;
            color: #c62828;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            border-left: 4px solid #c62828;
        }
        
        .price-info {
            background: #f8f8f8;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        
        .price-info h3 {
            color: #e60000;
            margin-bottom: 15px;
        }
        
        .price-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            padding-bottom: 10px;
            border-bottom: 1px solid #ddd;
        }
        
        .price-row.total {
            font-size: 1.3em;
            font-weight: bold;
            border-bottom: none;
            margin-top: 10px;
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
        
        .button-group {
            text-align: center;
            margin-top: 30px;
        }
        
        .required {
            color: #e60000;
        }
    </style>
    <script>
        function updatePrice() {
            var tipo = document.getElementById('tipoEntrada').value;
            var cantidad = parseInt(document.getElementById('cantidadEntradas').value) || 0;
            var precioUnitario = 0;
            
            if (tipo === 'GENERAL') {
                precioUnitario = 150;
            } else if (tipo === 'VIP') {
                precioUnitario = 450;
            }
            
            var total = precioUnitario * cantidad;
            
            document.getElementById('precioUnitario').textContent = '€' + precioUnitario.toFixed(2);
            document.getElementById('cantidadDisplay').textContent = cantidad;
            document.getElementById('precioTotal').textContent = '€' + total.toFixed(2);
        }
        
        window.onload = function() {
            document.getElementById('tipoEntrada').addEventListener('change', updatePrice);
            document.getElementById('cantidadEntradas').addEventListener('input', updatePrice);
            updatePrice();
        };
    </script>
</head>
<body>
    <div class="container">
        <h1>🎫 Comprar Entradas</h1>
        
        <div class="event-info">
            <h2><s:property value="event.nombre"/></h2>
            <p><strong>📍</strong> <s:property value="event.circuito"/> - <s:property value="event.ubicacion"/></p>
            <p><strong>📅</strong> <s:date name="event.fecha" format="dd/MM/yyyy HH:mm"/></p>
        </div>
        
        <s:if test="errorMessage != null">
            <div class="error-message">
                <strong>⚠️ Error:</strong> <s:property value="errorMessage"/>
            </div>
        </s:if>
        
        <div class="availability">
            <div class="availability-card general">
                <h3>🎟️ General</h3>
                <div class="count"><s:property value="event.entradasDisponibles"/></div>
                <p>Disponibles</p>
                <p><strong>€150.00</strong> por entrada</p>
            </div>
            <div class="availability-card vip">
                <h3>⭐ VIP</h3>
                <div class="count"><s:property value="event.entradasDisponibles"/></div>
                <p>Disponibles</p>
                <p><strong>€450.00</strong> por entrada</p>
            </div>
        </div>
        
        <s:form action="purchase-process" method="post">
            <div class="form-group">
                <label for="nombreComprador">Nombre Completo <span class="required">*</span></label>
                <s:textfield name="nombreComprador" id="nombreComprador" placeholder="Ej: Juan Pérez García"/>
                <s:fielderror fieldName="nombreComprador" cssClass="error"/>
            </div>
            
            <div class="form-group">
                <label for="email">Email <span class="required">*</span></label>
                <s:textfield name="email" id="email" type="email" placeholder="tu@email.com"/>
                <s:fielderror fieldName="email" cssClass="error"/>
            </div>
            
            <div class="form-group">
                <label for="telefono">Teléfono <span class="required">*</span></label>
                <s:textfield name="telefono" id="telefono" type="tel" placeholder="+34 600 000 000"/>
                <s:fielderror fieldName="telefono" cssClass="error"/>
            </div>
            
            <div class="form-group">
                <label for="tipoEntrada">Tipo de Entrada <span class="required">*</span></label>
                <s:select name="tipoEntrada" id="tipoEntrada" list="{'GENERAL', 'VIP'}" 
                          headerKey="" headerValue="-- Seleccione un tipo --"/>
                <s:fielderror fieldName="tipoEntrada" cssClass="error"/>
            </div>
            
            <div class="form-group">
                <label for="cantidadEntradas">Cantidad de Entradas <span class="required">*</span></label>
                <s:textfield name="cantidadEntradas" id="cantidadEntradas" type="number" 
                            min="1" max="10" value="1"/>
                <s:fielderror fieldName="cantidadEntradas" cssClass="error"/>
                <div style="color: #666; font-size: 0.9em; margin-top: 5px;">
                    Máximo 10 entradas por compra
                </div>
            </div>
            
            <div class="price-info">
                <h3>💰 Resumen del Precio</h3>
                <div class="price-row">
                    <span>Precio por entrada:</span>
                    <span id="precioUnitario">€0.00</span>
                </div>
                <div class="price-row">
                    <span>Cantidad:</span>
                    <span id="cantidadDisplay">0</span>
                </div>
                <div class="price-row total">
                    <span>TOTAL:</span>
                    <span id="precioTotal">€0.00</span>
                </div>
            </div>
            
            <div class="button-group">
                <s:submit value="🛒 Confirmar Compra" cssClass="btn btn-primary"/>
                <a href="${pageContext.request.contextPath}/" class="btn btn-secondary">❌ Cancelar</a>
            </div>
        </s:form>
    </div>
</body>
</html>