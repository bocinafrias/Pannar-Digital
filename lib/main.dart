import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/supabase_config.dart';
import 'utils/app_router.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'services/data_notification_service.dart';
import 'services/appointment_notification_service.dart';
import 'dart:io' show Platform;

// Importar sqflite_common_ffi para Windows (desktop)
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar sqflite_common_ffi para Windows
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      debugPrint('Error inicializando sqflite_common_ffi: $e');
    }
  }

  // Inicializar datos de fecha para el locale español
  await initializeDateFormatting('es', null);

  // Inicializar notificaciones nativas de Windows (RF-10)
  await AppointmentNotificationService.initialize();

  // Credenciales de Supabase configuradas
  await SupabaseConfig.initialize(
    url: 'https://myptatolrokyulgjlouk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15cHRhdG9scm9reXVsZ2psb3VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyMjE3NzcsImV4cCI6MjA4MDc5Nzc3N30.Dlmp3Lu7yMQdC2pQFGrIDIIYSryISMw0iqHOehSfpns',
  );

  // Ping keep-alive para evitar que Supabase free-tier pause el proyecto
  // por inactividad. Se ejecuta máximo una vez cada 4 días.
  SyncService().keepAlive();

  runApp(const PannarDigitalApp());
}

class PannarDigitalApp extends StatelessWidget {
  const PannarDigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..init()),
        ChangeNotifierProvider(create: (_) => DataNotificationService()),
        Provider(create: (_) => SyncService()),
      ],
      child: MaterialApp.router(
        title: 'PANNAR Digital',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es', 'ES'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
          Locale('en', 'US'),
        ],
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xFF1E3A5F),
          fontFamily: 'Roboto',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A5F),
          ),
        ),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
