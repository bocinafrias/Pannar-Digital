import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import '../widgets/welcome_section.dart';
import '../widgets/summary_cards.dart';
import '../widgets/agenda_section.dart';
import '../widgets/recent_activity_section.dart';
import '../widgets/weekly_summary_section.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/data_notification_service.dart';
import '../services/appointment_notification_service.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseService();
  int _todayAppointments = 0;
  int _activePatients = 0;
  int _upcomingAppointments = 0;
  int _reportsGenerated = 0;
  List<AppointmentModel> _todayAgenda = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Escuchar cambios en los datos
    final notificationService =
        Provider.of<DataNotificationService>(context, listen: false);
    notificationService.addListener(_loadDashboardData);
    // RF-10: Lanzar notificaciones de citas del día al entrar al dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNotifications());
  }

  @override
  void dispose() {
    // Remover listener para evitar memory leaks
    final notificationService =
        Provider.of<DataNotificationService>(context, listen: false);
    notificationService.removeListener(_loadDashboardData);
    super.dispose();
  }

  void _startNotifications() {
    final user = context.read<AuthService>().currentUserModel;
    if (user != null) {
      AppointmentNotificationService().start(user);
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUserModel;
      
      // Si es psicólogo, filtrar por su nombre; si es admin, no filtrar (null)
      String? psychologistId;
      String? psychologistName;
      if (currentUser != null && currentUser.role != UserRole.admin) {
        psychologistId = currentUser.id;
        psychologistName = currentUser.name; // Usar nombre para búsqueda flexible
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Cargar citas de hoy
      final todayAppointments = await _db.getAppointments(
        psychologistId: psychologistId,
        psychologistName: psychologistName,
        startDate: todayStart,
        endDate: todayEnd,
      );

      // Cargar pacientes activos
      final patients = await _db.getPatients(
        psychologistId: psychologistId,
        psychologistName: psychologistName,
      );

      // Cargar próximas citas (esta semana)
      final weekStart = todayStart;
      final weekEnd = weekStart.add(const Duration(days: 7));
      final upcomingAppointments = await _db.getAppointments(
        psychologistId: psychologistId,
        psychologistName: psychologistName,
        startDate: weekStart,
        endDate: weekEnd,
      );

      // Cargar reportes generados
      final reportsCount = await _db.getReportsCount();

      setState(() {
        _todayAppointments = todayAppointments.length;
        _activePatients = patients.length;
        _upcomingAppointments = upcomingAppointments.length;
        _todayAgenda = todayAppointments.take(3).toList();
        _reportsGenerated = reportsCount;
      });
    } catch (e) {
      print('Error cargando datos del dashboard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userName = authService.currentUserModel?.name ?? 'Usuario';

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          const Sidebar(),
          // Main Content
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Top Bar
                  TopBar(userName: userName),
                  // Scrollable Content
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadDashboardData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Welcome Section
                            WelcomeSection(
                              userName: userName,
                              todayAppointments: _todayAppointments,
                              userGender:
                                  null, // TODO: Obtener del usuario si está disponible
                            ),
                            const SizedBox(height: 24),
                            // Summary Cards
                            SummaryCards(
                              todayAppointments: _todayAppointments,
                              activePatients: _activePatients,
                              upcomingAppointments: _upcomingAppointments,
                              reportsGenerated: _reportsGenerated,
                            ),
                            const SizedBox(height: 24),
                            // Two Column Layout
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column - Agenda
                                Expanded(
                                  flex: 1,
                                  child:
                                      AgendaSection(appointments: _todayAgenda),
                                ),
                                const SizedBox(width: 24),
                                // Right Column - Recent Activity
                                Expanded(
                                  flex: 1,
                                  child: Builder(
                                    builder: (context) {
                                      final currentUser = context.read<AuthService>().currentUserModel;
                                      final isAdmin = currentUser?.role == UserRole.admin;
                                      return RecentActivitySection(
                                        psychologistId: isAdmin ? null : currentUser?.id,
                                        psychologistName: isAdmin ? null : currentUser?.name,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Weekly Summary
                            Builder(
                              builder: (context) {
                                final currentUser = context.read<AuthService>().currentUserModel;
                                final isAdmin = currentUser?.role == UserRole.admin;
                                return WeeklySummarySection(
                                  psychologistId: isAdmin ? null : currentUser?.id,
                                  psychologistName: isAdmin ? null : currentUser?.name,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
