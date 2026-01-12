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
              '''
              <!DOCTYPE html>
              <html>
              <head>
                <title>Error de autenticación</title>
                <meta charset="UTF-8">
                <style>
                  body {
                    font-family: Arial, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background: #f5f5f5;
                  }
                  .container {
                    text-align: center;
                    padding: 40px;
                    background: white;
                    border-radius: 8px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                  }
                  h1 { color: #d32f2f; }
                  p { color: #666; }
                </style>
              </head>
              <body>
                <div class="container">
                  <h1>❌ Error de autenticación</h1>
                  <p>Ocurrió un error: $error</p>
                  <p>Puedes cerrar esta ventana e intentar de nuevo.</p>
                </div>
              </body>
              </html>
              ''',
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
              '''
              <!DOCTYPE html>
              <html>
              <head>
                <title>Autenticación exitosa</title>
                <meta charset="UTF-8">
                <style>
                  body {
                    font-family: Arial, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background: #f5f5f5;
                  }
                  .container {
                    text-align: center;
                    padding: 40px;
                    background: white;
                    border-radius: 8px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                  }
                  h1 { color: #2e7d32; }
                  p { color: #666; }
                  .spinner {
                    border: 4px solid #f3f3f3;
                    border-top: 4px solid #1E3A5F;
                    border-radius: 50%;
                    width: 40px;
                    height: 40px;
                    animation: spin 1s linear infinite;
                    margin: 20px auto;
                  }
                  @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                  }
                </style>
              </head>
              <body>
                <div class="container">
                  <h1>✅ Autenticación exitosa</h1>
                  <p>Tu sesión ha sido iniciada correctamente.</p>
                  <p>Puedes cerrar esta ventana y volver a la aplicación.</p>
                  <div class="spinner"></div>
                </div>
              </body>
              </html>
              ''',
              200,
            );

            if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
              _codeCompleter!.complete(code);
            }
          } else {
            // Si no hay código, enviar respuesta por defecto
            _sendResponse(
              request,
              '''
              <!DOCTYPE html>
              <html>
              <head>
                <title>Callback OAuth</title>
                <meta charset="UTF-8">
              </head>
              <body>
                <h1>Procesando autenticación...</h1>
              </body>
              </html>
              ''',
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
