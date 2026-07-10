<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" isErrorPage="true"%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>500 — Error interno · F1 Tickets 2026</title>
    <style>
        body { margin: 0; font-family: Arial, sans-serif; background: #1a1a1a; color: #fff; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
        .box { text-align: center; padding: 60px 40px; }
        .code { font-size: 8em; font-weight: bold; color: #e60000; line-height: 1; }
        h1 { font-size: 1.8em; margin: 10px 0 20px; color: #ffcc00; }
        p { color: #ccc; margin-bottom: 30px; }
        a { display: inline-block; padding: 12px 30px; background: #e60000; color: #fff; text-decoration: none; border-radius: 4px; font-weight: bold; }
        a:hover { background: #ff1a1a; }
    </style>
</head>
<body>
    <div class="box">
        <div class="code">500</div>
        <h1>Error interno del servidor</h1>
        <p>Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.</p>
        <a href="${pageContext.request.contextPath}/dashboard">Volver al inicio</a>
    </div>
</body>
</html>
