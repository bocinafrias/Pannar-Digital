import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../config/supabase_config.dart';
import '../models/user_model.dart';
import 'local_auth_service.dart';
import 'local_oauth_server.dart';

class AuthService extends ChangeNotifier {
  final _supabase = SupabaseConfig.client;
  final _localAuth = LocalAuthService();
  final _connectivity = Connectivity();
  StreamSubscription<AuthState>? _authSubscription;

  // Lista de correos que son administradores
  // Puedes modificar esta lista según tus necesidades
  static const List<String> _adminEmails = [
    'emanuelfrias43@gmail.com',
    'rodriguezhernandezangelmario0@gmail.com',
    // Agrega más correos de administradores aquí cuando los tengas
  ];

  // Verificar si un correo pertenece a un administrador
  bool _isAdminEmail(String email) {
    return _adminEmails.contains(email.toLowerCase());
  }

  // Obtener todos los usuarios (psicólogos y admin)
  Future<List<UserModel>> getUsers() async {
    try {
      final response = await _supabase.from('users').select().order('name');

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => UserModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo usuarios: $e');
      return [];
    }
  }

  // Obtener solo psicólogos
  Future<List<UserModel>> getPsychologists() async {
    try {
      final users = await getUsers();
      return users.where((user) => user.role == UserRole.psychologist).toList();
    } catch (e) {
      debugPrint('Error obteniendo psicólogos: $e');
      return [];
    }
  }

  // Iniciar sesión con Google usando OAuth de Supabase (funciona en desktop)
  Future<UserModel?> signInWithGoogle({String? pin}) async {
    LocalOAuthServer? localServer;

    try {
      // Verificar conexión
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;

      if (!hasConnection) {
        throw Exception(
          'Se requiere conexión a internet para la primera autenticación',
        );
      }

      // IMPORTANTE: Iniciar el servidor local ANTES de abrir el navegador
      localServer = LocalOAuthServer(port: 3000);

      // Iniciar el servidor y configurar los manejadores
      debugPrint('🚀 Iniciando servidor local en puerto 3000...');
      final codeFuture = localServer.startAndWaitForCode();

      // Esperar un momento para asegurar que el servidor esté completamente listo
      await Future.delayed(const Duration(milliseconds: 1000));
      debugPrint('✅ Servidor local listo, iniciando flujo OAuth...');

      // Ahora iniciar el flujo OAuth con redirectTo al servidor local
      // Usar prompt: 'select_account' para permitir elegir cuenta diferente
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        authScreenLaunchMode: LaunchMode.externalApplication,
        redirectTo: 'http://localhost:3000', // Redirige al servidor local
        queryParams: {
          'prompt': 'select_account', // Forzar selección de cuenta
        },
      );

      debugPrint(
          '🌐 Navegador abierto, esperando callback en servidor local...');

      // Esperar a recibir el código en el servidor local
      final code = await codeFuture;
      debugPrint('✅ Código OAuth recibido: ${code.substring(0, 20)}...');

      // Pausa adicional para que el servidor pueda responder al navegador
      await Future.delayed(const Duration(milliseconds: 500));

      // Intercambiar el código por una sesión de Supabase
      // Construir la URL completa del redirect para que Supabase pueda procesar todos los parámetros
      final redirectUrl = 'http://localhost:3000/?code=$code';
      debugPrint('🔄 Intercambiando código por sesión...');

      // Intentar obtener la sesión desde la URL (Supabase procesará el código automáticamente)
      final response = await _supabase.auth.getSessionFromUrl(
        Uri.parse(redirectUrl),
      );

      debugPrint('✅ Sesión establecida exitosamente');
      final user = response.session.user;

      // Obtener o crear el usuario en la base de datos
      UserModel? userModel;
      try {
        userModel = await _getOrCreateUser(user);
      } catch (e) {
        // Si falla al obtener/crear en Supabase (por ejemplo, error de políticas RLS),
        // crear usuario local con la información disponible
        debugPrint(
            'Error obteniendo usuario de Supabase, creando usuario local: $e');
        final email = user.email ?? '';
        final isAdmin = _isAdminEmail(email);
        userModel = UserModel(
          id: user.id,
          name: user.userMetadata?['full_name'] ??
              user.email?.split('@')[0] ??
              'Usuario',
          email: email,
          role: isAdmin ? UserRole.admin : UserRole.psychologist,
          createdAt: DateTime.now(),
        );
        // No lanzar excepción, continuar con el usuario local
      }

      // Guardar usuario localmente para acceso offline
      await _localAuth.saveUserLocally(userModel, pin: pin);
      _currentUserModel = userModel;
      notifyListeners();

      return userModel;
    } catch (e) {
      debugPrint('Error en signInWithGoogle: $e');
      // Si el usuario ya está cargado localmente, no lanzar excepción
      if (_currentUserModel != null) {
        debugPrint(
            'Usuario local disponible a pesar del error, continuando...');
        return _currentUserModel;
      }
      throw Exception('Error al iniciar sesión con Google: $e');
    } finally {
      // Asegurarse de cerrar el servidor local
      await localServer?.stop();
      debugPrint('Servidor local cerrado');
    }
  }

  // Autenticación offline con sesión local
  Future<UserModel?> signInOffline({String? pin}) async {
    try {
      // Verificar si hay sesión local
      final hasLocalSession = await _localAuth.hasLocalSession();
      if (!hasLocalSession) {
        return null;
      }

      // Si hay PIN, verificar
      if (pin != null && pin.isNotEmpty) {
        final hasPin = await _localAuth.hasPinConfigured();
        if (hasPin) {
          final isValid = await _localAuth.authenticateWithPin(pin);
          if (!isValid) {
            throw Exception('PIN incorrecto');
          }
        }
      }

      // Obtener usuario local
      final localUser = await _localAuth.getLocalUser();
      if (localUser != null) {
        _currentUserModel = localUser;
        notifyListeners();
        return localUser;
      }

      return null;
    } catch (e) {
      throw Exception('Error en autenticación offline: $e');
    }
  }

  // Verificar si hay sesión local disponible
  Future<bool> hasLocalSession() async {
    return await _localAuth.hasLocalSession();
  }

  // Verificar si tiene PIN configurado
  Future<bool> hasPinConfigured() async {
    return await _localAuth.hasPinConfigured();
  }

  // Configurar PIN para acceso offline
  Future<void> setPin(String pin) async {
    await _localAuth.setPin(pin);
  }

  // Obtener o crear usuario en la base de datos
  Future<UserModel> _getOrCreateUser(User user) async {
    try {
      // Buscar usuario existente
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        return UserModel.fromJson(response);
      }

      // Determinar rol: si el correo está en la lista de admin, es admin
      final email = user.email ?? '';
      final isAdmin = _isAdminEmail(email);

      // Crear nuevo usuario
      final newUser = UserModel(
        id: user.id,
        name:
            user.userMetadata?['full_name'] ?? email.split('@')[0] ?? 'Usuario',
        email: email,
        role: isAdmin ? UserRole.admin : UserRole.psychologist,
        createdAt: DateTime.now(),
      );

      // Intentar insertar en Supabase, pero si falla (p. ej. por políticas RLS),
      // simplemente devolver el modelo local
      try {
        await _supabase.from('users').insert(newUser.toJson());
      } catch (insertError) {
        debugPrint(
            'Error insertando usuario en Supabase (continuando con usuario local): $insertError');
        // Continuar sin error, el usuario local se guardará después
      }
      return newUser;
    } catch (e) {
      debugPrint('Error al obtener/crear usuario: $e');
      // Si hay error (incluyendo recursión infinita), crear usuario local
      final email = user.email ?? '';
      final isAdmin = _isAdminEmail(email);
      return UserModel(
        id: user.id,
        name:
            user.userMetadata?['full_name'] ?? email.split('@')[0] ?? 'Usuario',
        email: email,
        role: isAdmin ? UserRole.admin : UserRole.psychologist,
        createdAt: DateTime.now(),
      );
    }
  }

  // Registrar nuevo usuario (solo administradores)
  Future<UserModel> registerUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      // Crear usuario en Supabase Auth
      final response = await _supabase.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
        ),
      );

      if (response.user == null) {
        throw Exception('No se pudo crear el usuario');
      }

      // Crear registro en la tabla users
      final userModel = UserModel(
        id: response.user!.id,
        name: name,
        email: email,
        role: role,
        createdAt: DateTime.now(),
      );

      await _supabase.from('users').insert(userModel.toJson());
      return userModel;
    } catch (e) {
      throw Exception('Error al registrar usuario: $e');
    }
  }

  // Cerrar sesión
  Future<void> signOut({bool clearLocalSession = false}) async {
    try {
      // Limpiar primero el modelo de usuario para respuesta inmediata
      _currentUserModel = null;
      notifyListeners();

      // Limpiar sesión local si se solicita (incluir PIN si se está cerrando sesión completamente)
      if (clearLocalSession) {
        await _localAuth.clearLocalSession(clearPin: true);
      }

      // Intentar cerrar sesión en Supabase (no bloquear si falla)
      try {
        final connectivityResult = await _connectivity.checkConnectivity();
        final hasConnection = connectivityResult != ConnectivityResult.none;
        if (hasConnection) {
          // No esperar - hacer en background
          _supabase.auth.signOut().catchError((e) {
            debugPrint('Error cerrando sesión en Supabase (continuando): $e');
          });
        }
      } catch (e) {
        debugPrint('Error cerrando sesión en Supabase (continuando): $e');
      }
    } catch (e) {
      // Asegurar que el estado se limpia incluso si hay error
      _currentUserModel = null;
      notifyListeners();
      debugPrint('Error al cerrar sesión: $e');
    }
  }

  // Obtener usuario actual
  User? get currentUser => _supabase.auth.currentUser;

  // Verificar si hay sesión activa
  bool get isAuthenticated => currentUser != null;

  // Stream de cambios de autenticación
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;

  // Inicializar servicio
  Future<void> init() async {
    // NO cargar automáticamente la sesión local aquí si hay PIN configurado
    // Dejar que el login screen maneje la verificación de PIN si es necesario
    final hasPin = await _localAuth.hasPinConfigured();

    // Solo cargar sesión local si NO hay PIN configurado
    // Si hay PIN, el login screen debe manejar la verificación primero
    if (!hasPin) {
      final localUser = await _localAuth.getLocalUser();
      if (localUser != null) {
        _currentUserModel = localUser;
        notifyListeners();
      }
    }

    // Solo cargar sesión de Supabase si está autenticado (sesión activa en servidor)
    if (isAuthenticated) {
      await _loadCurrentUser();
    }

    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _loadCurrentUser();
      } else if (data.event == AuthChangeEvent.signedOut) {
        // No limpiar sesión local automáticamente al cerrar en Supabase
        // Solo actualizar si hay usuario local diferente y no hay PIN
        if (!hasPin) {
          _loadLocalUserIfNeeded();
        }
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    if (currentUser != null) {
      try {
        final response = await _supabase
            .from('users')
            .select()
            .eq('id', currentUser!.id)
            .maybeSingle();
        if (response != null) {
          _currentUserModel = UserModel.fromJson(response);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error cargando usuario de Supabase: $e');
        // Si falla al cargar de Supabase, intentar cargar usuario local como fallback
        try {
          final localUser = await _localAuth.getLocalUser();
          if (localUser != null) {
            _currentUserModel = localUser;
            notifyListeners();
          } else {
            // Si no hay usuario local, crear uno básico desde currentUser
            _currentUserModel = UserModel(
              id: currentUser!.id,
              name: currentUser!.userMetadata?['full_name'] ??
                  currentUser!.email?.split('@')[0] ??
                  'Usuario',
              email: currentUser!.email ?? '',
              role: UserRole.psychologist,
              createdAt: DateTime.now(),
            );
            notifyListeners();
          }
        } catch (localError) {
          debugPrint('Error cargando usuario local: $localError');
          // Crear usuario mínimo desde currentUser
          _currentUserModel = UserModel(
            id: currentUser!.id,
            name: currentUser!.userMetadata?['full_name'] ??
                currentUser!.email?.split('@')[0] ??
                'Usuario',
            email: currentUser!.email ?? '',
            role: UserRole.psychologist,
            createdAt: DateTime.now(),
          );
          notifyListeners();
        }
      }
    }
  }

  // Recargar usuario actual (público para uso externo)
  Future<void> reloadCurrentUser() async {
    // Primero intentar cargar usuario local (sesión guardada)
    final localUser = await _localAuth.getLocalUser();
    if (localUser != null) {
      _currentUserModel = localUser;
      notifyListeners();
    }

    // Si hay sesión de Supabase activa, también intentar cargar de Supabase
    if (isAuthenticated) {
      await _loadCurrentUser();
    }
  }

  Future<void> _loadLocalUserIfNeeded() async {
    if (_currentUserModel == null) {
      final localUser = await _localAuth.getLocalUser();
      if (localUser != null) {
        _currentUserModel = localUser;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
