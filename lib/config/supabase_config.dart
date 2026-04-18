import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Credenciales leídas en tiempo de compilación.
  // Se pasan con: flutter build/run --dart-define-from-file=.env
  // El archivo .env está en .gitignore (ver .env.example como plantilla).
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Credenciales de Supabase no configuradas. Crea un archivo .env '
        '(usa .env.example como plantilla) y compila con '
        '--dart-define-from-file=.env',
      );
    }
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        // Configuración para desktop - usar PKCE flow
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
