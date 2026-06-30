<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib prefix="s" uri="/struts-tags" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gran Premio de España 2026 - Venta de Entradas</title>
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
            background: rgba(0, 0, 0, 0.5);
        }
        
        .hero h1 {
            font-size: 3.5em;
            margin-bottom: 20px;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.8);
            letter-spacing: 2px;
        }
        
        .hero .subtitle {
            font-size: 1.5em;
            margin-bottom: 10px;
            color: #ffcc00;
        }
        
        .hero .date {
            font-size: 1.2em;
            margin-bottom: 30px;
            color: #ccc;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin-bottom: 50px;
        }
        
        .feature-card {
            background: rgba(255, 255, 255, 0.1);
            padding: 30px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: transform 0.3s;
        }
        
        .feature-card:hover {
            transform: translateY(-5px);
            background: rgba(255, 255, 255, 0.15);
        }
        
        .feature-card h3 {
            color: #ffcc00;
            margin-bottom: 15px;
            font-size: 1.5em;
        }
        
        .cta-section {
            text-align: center;
            padding: 50px 20px;
            background: rgba(0, 0, 0, 0.6);
            border-radius: 15px;
            margin-bottom: 30px;
        }
        
        .cta-section h2 {
            font-size: 2.5em;
            margin-bottom: 20px;
            color: #ffcc00;
        }
        
        .btn {
            display: inline-block;
            padding: 15px 40px;
            margin: 10px;
            font-size: 1.2em;
            text-decoration: none;
            border-radius: 5px;
            transition: all 0.3s;
            font-weight: bold;
            text-transform: uppercase;
        }
        
        .btn-primary {
            background: #e60000;
            color: #fff;
            border: 2px solid #e60000;
        }
        
        .btn-primary:hover {
            background: #ff1a1a;
            transform: scale(1.05);
        }
        
        .btn-secondary {
            background: transparent;
            color: #fff;
            border: 2px solid #fff;
        }
        
        .btn-secondary:hover {
            background: #fff;
            color: #000;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        
        .info-box {
            background: rgba(255, 255, 255, 0.1);
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        
        .info-box .label {
            color: #ffcc00;
            font-size: 0.9em;
            margin-bottom: 10px;
        }
        
        .info-box .value {
            font-size: 2em;
            font-weight: bold;
        }
        
        footer {
            text-align: center;
            padding: 20px;
            background: rgba(0, 0, 0, 0.8);
            margin-top: 50px;
        }
    </style>
</head>
<body>
    <div class="hero">
        <h1>🏎️ GRAN PREMIO DE ESPAÑA 2026</h1>
        <p class="subtitle">Circuit de Barcelona-Catalunya</p>
        <p class="date">📅 15 de Septiembre 2026 | 14:00h</p>
    </div>
    
    <div class="container">
        <div class="features">
            <div class="feature-card">
                <h3>🎫 Entradas Limitadas</h3>
                <p>Solo 1000 entradas disponibles para este evento exclusivo. ¡No te quedes sin la tuya!</p>
            </div>
            
            <div class="feature-card">
                <h3>⚡ Dos Categorías</h3>
                <p><strong>General:</strong> €150 - Vive la emoción desde las gradas principales<br>
                   <strong>VIP:</strong> €450 - Acceso premium con servicios exclusivos</p>
            </div>
            
            <div class="feature-card">
                <h3>🏁 Experiencia Única</h3>
                <p>Disfruta de la velocidad, la adrenalina y el espectáculo del automovilismo de élite en uno de los circuitos más emblemáticos.</p>
            </div>
        </div>
        
        <div class="cta-section">
            <h2>¡Consigue tus Entradas Ahora!</h2>
            <p style="font-size: 1.2em; margin-bottom: 30px;">
                Compra tus entradas de forma rápida y segura
            </p>
            
            <a href="purchase-form" class="btn btn-primary">🎟️ Comprar Entradas</a>
            <a href="ticket-list" class="btn btn-secondary">Ver Disponibilidad</a>
            <a href="event-info" class="btn btn-secondary">Información del Evento</a>
            
            <div class="info-grid">
                <div class="info-box">
                    <div class="label">Capacidad Total</div>
                    <div class="value">1000</div>
                </div>
                <div class="info-box">
                    <div class="label">Entradas General</div>
                    <div class="value">700</div>
                </div>
                <div class="info-box">
                    <div class="label">Entradas VIP</div>
                    <div class="value">300</div>
                </div>
            </div>
        </div>
        
        <div style="text-align: center; margin-top: 40px;">
            <a href="dashboard" class="btn btn-secondary" style="font-size: 1em;">📊 Panel de Administración</a>
        </div>
    </div>
    
    <footer>
        <p>&copy; 2026 Gran Premio de España - Sistema de Venta de Entradas F1</p>
        <p style="margin-top: 10px; font-size: 0.9em; color: x#999;">API version</p>
    </footer>
</body>
</html>