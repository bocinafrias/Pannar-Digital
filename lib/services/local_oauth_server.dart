import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Servidor HTTP local para capturar el callback de OAuth en aplicaciones desktop
class LocalOAuthServer {
  HttpServer? _server;
  final int port;
  Completer<String>? _codeCompleter;
  bool _isListening = false;

  LocalOAuthServer({this.port = 3000});

  /// Inicia el servidor sin esperar el código (útil para verificar que esté activo)
  Future<void> start() async {
    if (_server != null) {
      debugPrint('⚠️ El servidor ya está iniciado');
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _isListening = true;
      debugPrint('✅ Servidor OAuth local iniciado en http://localhost:$port');
    } catch (e) {
      _isListening = false;
      debugPrint('❌ Error iniciando servidor OAuth: $e');
      rethrow;
    }
  }

  /// Configura los manejadores de peticiones y espera el código
  Future<String> startAndWaitForCode() async {
    _codeCompleter = Completer<String>();

    // Si el servidor no está iniciado, iniciarlo
    if (_server == null || !_isListening) {
      await start();
    }

    try {
      // Configurar el manejador de peticiones
      _server!.listen((request) async {
        try {
          final uri = request.uri;

          debugPrint('Request recibido: ${uri.toString()}');

          // Buscar el código de autorización en los parámetros
          final code = uri.queryParameters['code'];
          final error = uri.queryParameters['error'];

          if (error != null) {
            // Si hay un error, enviar página de error
            _sendResponse(
              request,
              '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Error de autenticación — PANNAR Digital</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0f2340 0%, #1E3A5F 60%, #2a5298 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .card {
      background: #fff;
      border-radius: 16px;
      padding: 48px 56px;
      width: 420px;
      text-align: center;
      box-shadow: 0 24px 64px rgba(0,0,0,0.3);
      animation: slideUp .4s cubic-bezier(.16,1,.3,1) both;
    }
    @keyframes slideUp {
      from { opacity: 0; transform: translateY(24px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    .icon-wrap {
      width: 72px; height: 72px;
      background: #fff0f0;
      border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      margin: 0 auto 24px;
    }
    .icon-wrap svg { width: 36px; height: 36px; }
    .brand { font-size: 12px; font-weight: 600; letter-spacing: 2px; color: #1E3A5F; text-transform: uppercase; margin-bottom: 20px; }
    h1 { font-size: 22px; font-weight: 700; color: #c0392b; margin-bottom: 10px; }
    .msg { font-size: 14px; color: #555; line-height: 1.6; margin-bottom: 6px; }
    .hint { font-size: 13px; color: #999; margin-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">PANNAR Digital</div>
    <div class="icon-wrap">
      <svg viewBox="0 0 24 24" fill="none" stroke="#c0392b" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="10"/>
        <line x1="15" y1="9" x2="9" y2="15"/>
        <line x1="9" y1="9" x2="15" y2="15"/>
      </svg>
    </div>
    <h1>Error de autenticación</h1>
    <p class="msg">Ocurrió un problema al iniciar sesión.</p>
    <p class="msg" style="color:#c0392b; font-size:13px;">$error</p>
    <p class="hint">Puedes cerrar esta ventana e intentar de nuevo.</p>
  </div>
</body>
</html>''',
              400,
            );

            if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
              _codeCompleter!.completeError(Exception('Error OAuth: $error'));
            }
            return;
          }

          if (code != null) {
            // Si tenemos el código, enviar página de éxito y completar el futuro
            _sendResponse(
              request,
              '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Autenticación exitosa — PANNAR Digital</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0f2340 0%, #1E3A5F 60%, #2a5298 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .card {
      background: #fff;
      border-radius: 16px;
      padding: 48px 56px;
      width: 420px;
      text-align: center;
      box-shadow: 0 24px 64px rgba(0,0,0,0.3);
      animation: slideUp .45s cubic-bezier(.16,1,.3,1) both;
    }
    @keyframes slideUp {
      from { opacity: 0; transform: translateY(28px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    .brand {
      font-size: 11px; font-weight: 700; letter-spacing: 2.5px;
      color: #1E3A5F; text-transform: uppercase; margin-bottom: 28px;
      opacity: .7;
    }
    /* Círculo animado con checkmark SVG */
    .check-wrap {
      width: 80px; height: 80px; margin: 0 auto 28px;
      position: relative;
    }
    .check-circle {
      fill: none; stroke: #1E3A5F; stroke-width: 2.5;
      stroke-dasharray: 251; stroke-dashoffset: 251;
      animation: drawCircle .6s .1s ease forwards;
    }
    .check-mark {
      fill: none; stroke: #1E3A5F; stroke-width: 3;
      stroke-linecap: round; stroke-linejoin: round;
      stroke-dasharray: 50; stroke-dashoffset: 50;
      animation: drawCheck .4s .65s ease forwards;
    }
    @keyframes drawCircle {
      to { stroke-dashoffset: 0; }
    }
    @keyframes drawCheck {
      to { stroke-dashoffset: 0; }
    }
    h1 { font-size: 22px; font-weight: 700; color: #1E3A5F; margin-bottom: 10px; }
    .msg { font-size: 14px; color: #555; line-height: 1.7; }
    .divider { width: 40px; height: 3px; background: #1E3A5F; border-radius: 2px; margin: 20px auto; opacity: .2; }
    .hint { font-size: 13px; color: #aaa; margin-top: 4px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">PANNAR Digital</div>
    <div class="check-wrap">
      <svg viewBox="0 0 80 80" width="80" height="80">
        <circle class="check-circle" cx="40" cy="40" r="36"/>
        <polyline class="check-mark" points="24,41 35,52 56,29"/>
      </svg>
    </div>
    <h1>Autenticación exitosa</h1>
    <div class="divider"></div>
    <p class="msg">Tu sesión ha sido iniciada correctamente.</p>
    <p class="hint">Puedes cerrar esta ventana y volver a la aplicación.</p>
  </div>
</body>
</html>''',
              200,
            );

            if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
              _codeCompleter!.complete(code);
            }
          } else {
            // Si no hay código, enviar respuesta por defecto
            _sendResponse(
              request,
              '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PANNAR Digital</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0f2340 0%, #1E3A5F 60%, #2a5298 100%);
      min-height: 100vh;
      display: flex; align-items: center; justify-content: center;
    }
    .card {
      background: #fff; border-radius: 16px; padding: 48px 56px; width: 420px;
      text-align: center; box-shadow: 0 24px 64px rgba(0,0,0,0.3);
    }
    .brand { font-size: 11px; font-weight: 700; letter-spacing: 2.5px; color: #1E3A5F; text-transform: uppercase; margin-bottom: 24px; opacity: .7; }
    .spinner {
      width: 44px; height: 44px; margin: 0 auto 24px;
      border: 3px solid #e8eef5;
      border-top-color: #1E3A5F;
      border-radius: 50%;
      animation: spin .9s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    h1 { font-size: 20px; font-weight: 600; color: #1E3A5F; }
    p { font-size: 13px; color: #aaa; margin-top: 8px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">PANNAR Digital</div>
    <div class="spinner"></div>
    <h1>Procesando autenticación…</h1>
    <p>Por favor espera un momento.</p>
  </div>
</body>
</html>''',
              200,
            );
          }
        } catch (e) {
          debugPrint('Error procesando request: $e');
          _sendResponse(request, 'Error interno', 500);
        }
      }, onError: (error) {
        debugPrint('Error en servidor OAuth: $error');
        if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
          _codeCompleter!.completeError(error);
        }
      });

      // Pausa CRÍTICA: Esperar a que el servidor esté completamente listo para recibir conexiones
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('✅ Servidor OAuth listo para recibir conexiones');

      // Esperar a recibir el código (con timeout de 5 minutos)
      final code = await _codeCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException(
              'Tiempo de espera agotado esperando código OAuth');
        },
      );

      return code;
    } catch (e) {
      debugPrint('Error iniciando servidor OAuth: $e');
      if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
        _codeCompleter!.completeError(e);
      }
      rethrow;
    }
    // NO detener el servidor aquí - se detendrá después de procesar la sesión
  }

  /// Envía una respuesta HTTP al cliente
  void _sendResponse(HttpRequest request, String content, int statusCode) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.html
      ..headers.add('Access-Control-Allow-Origin', '*')
      ..write(content)
      ..close();
  }

  /// Detiene el servidor local
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('Servidor OAuth local detenido');
    }
  }
}
