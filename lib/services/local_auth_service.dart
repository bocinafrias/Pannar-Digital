import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';

class LocalAuthService {
  static const String _userKey = 'logged_user';
  static const String _authTokenKey = 'auth_token';
  static const String _authTokenIssuedAtKey = 'auth_token_issued_at';
  static const String _pinKey = 'user_pin';
  static const String _pinSaltKey = 'user_pin_salt';
  static const String _lastSyncKey = 'last_sync';

  // La sesión local caduca 30 días después del último login/PIN exitoso.
  static const Duration _tokenValidity = Duration(days: 30);
  // PBKDF2-HMAC-SHA256: 100k iteraciones encarece el brute force del PIN.
  static const int _pinIterations = 100000;
  static const int _saltLength = 32;

  // Guardar usuario autenticado localmente
  Future<void> saveUserLocally(UserModel user, {String? pin}) async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar usuario
    await prefs.setString(_userKey, jsonEncode(user.toJson()));

    // Generar token de autenticación local con expiración
    final token = _generateAuthToken(user.id);
    await prefs.setString(_authTokenKey, token);
    await prefs.setInt(
      _authTokenIssuedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    // Guardar PIN si se proporciona (con salt + key stretching)
    if (pin != null && pin.isNotEmpty) {
      await _storeNewPinHash(prefs, pin);
    }

    // Guardar timestamp de última sincronización
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  // Obtener usuario almacenado localmente
  Future<UserModel?> getLocalUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson == null) return null;

    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(userMap);
    } catch (e) {
      return null;
    }
  }

  // Verificar si hay sesión local activa Y no expirada
  Future<bool> hasLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_authTokenKey);
    if (token == null) return false;

    var issuedAt = prefs.getInt(_authTokenIssuedAtKey);
    if (issuedAt == null) {
      // Sesión legacy sin timestamp: migrar fijando "ahora" para que
      // a partir de este momento aplique la política de expiración.
      issuedAt = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_authTokenIssuedAtKey, issuedAt);
    }

    final age = DateTime.now().millisecondsSinceEpoch - issuedAt;
    return age < _tokenValidity.inMilliseconds;
  }

  // Autenticación offline con PIN
  Future<bool> authenticateWithPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPinHash = prefs.getString(_pinKey);

    if (storedPinHash == null) return false;

    final saltB64 = prefs.getString(_pinSaltKey);
    bool isValid;

    if (saltB64 != null) {
      // Formato nuevo: PBKDF2-HMAC-SHA256 con salt aleatorio.
      final inputHash = _pbkdf2(pin, base64Decode(saltB64), _pinIterations);
      isValid = _constantTimeEquals(storedPinHash, inputHash);
    } else {
      // Formato legacy (SHA-256 sin salt): validar y migrar al formato nuevo.
      final legacyHash = sha256.convert(utf8.encode(pin)).toString();
      isValid = _constantTimeEquals(storedPinHash, legacyHash);
      if (isValid) {
        await _storeNewPinHash(prefs, pin);
      }
    }

    if (isValid) {
      // Renovar la sesión: cada PIN exitoso resetea el contador de 30 días.
      await prefs.setInt(
        _authTokenIssuedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    return isValid;
  }

  // Establecer PIN para acceso offline
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await _storeNewPinHash(prefs, pin);
  }

  // Verificar si tiene PIN configurado
  Future<bool> hasPinConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) != null;
  }

  // Eliminar PIN (desactiva acceso offline con PIN)
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_pinSaltKey);
  }

  // Limpiar sesión local
  Future<void> clearLocalSession({bool clearPin = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_authTokenKey);
    await prefs.remove(_authTokenIssuedAtKey);
    // Si se solicita, también eliminar el PIN (útil cuando se cierra sesión completamente)
    if (clearPin) {
      await prefs.remove(_pinKey);
      await prefs.remove(_pinSaltKey);
    }
  }

  // Obtener última sincronización
  Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);

    if (lastSyncStr == null) return null;

    try {
      return DateTime.parse(lastSyncStr);
    } catch (e) {
      return null;
    }
  }

  // Actualizar última sincronización
  Future<void> updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  // Generar token de autenticación con nonce aleatorio
  String _generateAuthToken(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = base64Encode(_randomBytes(16));
    final data = '$userId-$timestamp-$nonce';
    return sha256.convert(utf8.encode(data)).toString();
  }

  // Genera salt nuevo y guarda hash + salt en SharedPreferences.
  Future<void> _storeNewPinHash(SharedPreferences prefs, String pin) async {
    final salt = _randomBytes(_saltLength);
    final hash = _pbkdf2(pin, salt, _pinIterations);
    await prefs.setString(_pinKey, hash);
    await prefs.setString(_pinSaltKey, base64Encode(salt));
  }

  // PBKDF2-HMAC-SHA256 (un solo bloque, salida de 32 bytes).
  String _pbkdf2(String password, Uint8List salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    // Bloque inicial: salt || INT(1) en big-endian.
    final initial = Uint8List(salt.length + 4)
      ..setAll(0, salt)
      ..setAll(salt.length, [0, 0, 0, 1]);
    var u = Uint8List.fromList(hmac.convert(initial).bytes);
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return base64Encode(result);
  }

  Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rand.nextInt(256);
    }
    return bytes;
  }

  // Comparación en tiempo constante para evitar timing attacks.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
