import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';

class LocalAuthService {
  static const String _userKey = 'logged_user';
  static const String _authTokenKey = 'auth_token';
  static const String _pinKey = 'user_pin';
  static const String _lastSyncKey = 'last_sync';

  // Guardar usuario autenticado localmente
  Future<void> saveUserLocally(UserModel user, {String? pin}) async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar usuario
    await prefs.setString(_userKey, jsonEncode(user.toJson()));

    // Generar token de autenticación local
    final token = _generateAuthToken(user.id);
    await prefs.setString(_authTokenKey, token);

    // Guardar PIN si se proporciona
    if (pin != null && pin.isNotEmpty) {
      final pinHash = _hashPin(pin);
      await prefs.setString(_pinKey, pinHash);
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

  // Verificar si hay sesión local activa
  Future<bool> hasLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey) != null;
  }

  // Autenticación offline con PIN
  Future<bool> authenticateWithPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPinHash = prefs.getString(_pinKey);

    if (storedPinHash == null) return false;

    final inputPinHash = _hashPin(pin);
    return storedPinHash == inputPinHash;
  }

  // Establecer PIN para acceso offline
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final pinHash = _hashPin(pin);
    await prefs.setString(_pinKey, pinHash);
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
  }

  // Limpiar sesión local
  Future<void> clearLocalSession({bool clearPin = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_authTokenKey);
    // Si se solicita, también eliminar el PIN (útil cuando se cierra sesión completamente)
    if (clearPin) {
      await prefs.remove(_pinKey);
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

  // Generar token de autenticación
  String _generateAuthToken(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final data = '$userId-$timestamp';
    return sha256.convert(utf8.encode(data)).toString();
  }

  // Hash del PIN (SHA-256)
  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
}
