import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import 'database_service.dart';

/// RF-10: Notificaciones automáticas al psicólogo el día de la cita.
///
/// Al iniciar sesión muestra una notificación nativa de Windows por cada
/// cita programada para hoy. Repite la verificación cada hora mientras la
/// app permanezca abierta, evitando duplicados dentro del mismo día.
class AppointmentNotificationService {
  static final AppointmentNotificationService _instance =
      AppointmentNotificationService._internal();
  factory AppointmentNotificationService() => _instance;
  AppointmentNotificationService._internal();

  final _db = DatabaseService();
  Timer? _hourlyTimer;

  /// IDs de citas ya notificadas en la sesión actual.
  final Set<String> _notifiedIds = {};

  /// Fecha en que se limpió _notifiedIds por última vez.
  DateTime? _lastClearDate;

  /// Inicializa local_notifier. Llamar una sola vez en main() antes de runApp.
  static Future<void> initialize() async {
    await localNotifier.setup(appName: 'PANNAR Digital');
  }

  /// Inicia el servicio para el [user] que acaba de autenticarse.
  /// Lanza las notificaciones de hoy y programa una revisión horaria.
  Future<void> start(UserModel user) async {
    _resetIfNewDay();
    await _checkAndNotify(user);

    _hourlyTimer?.cancel();
    _hourlyTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      _resetIfNewDay();
      await _checkAndNotify(user);
    });
  }

  /// Detiene las revisiones periódicas (llamar al cerrar sesión).
  void stop() {
    _hourlyTimer?.cancel();
    _hourlyTimer = null;
    _notifiedIds.clear();
    _lastClearDate = null;
  }

  // ── Privados ─────────────────────────────────────────────────────────────

  void _resetIfNewDay() {
    final today = DateTime.now();
    if (_lastClearDate == null || _lastClearDate!.day != today.day) {
      _notifiedIds.clear();
      _lastClearDate = today;
    }
  }

  Future<void> _checkAndNotify(UserModel user) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Admin ve todas las citas; psicólogo solo las suyas.
      final appointments = await _db.getAppointments(
        psychologistId: user.role == UserRole.admin ? null : user.id,
        startDate: todayStart,
        endDate: todayEnd,
      );

      // Solo citas programadas que aún no se notificaron hoy.
      final pendientes = appointments
          .where((a) =>
              a.status == AppointmentStatus.scheduled &&
              !_notifiedIds.contains(a.id))
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

      for (final appointment in pendientes) {
        await _showNotification(appointment);
        _notifiedIds.add(appointment.id);
      }
    } catch (e) {
      debugPrint('AppointmentNotificationService._checkAndNotify error: $e');
    }
  }

  Future<void> _showNotification(AppointmentModel appointment) async {
    try {
      final patient = await _db.getPatientById(appointment.patientId);
      final patientName = patient?.name ?? 'Paciente';
      final timeStr = DateFormat('HH:mm').format(appointment.dateTime);

      final notification = LocalNotification(
        title: 'Cita hoy — PANNAR Digital',
        body: '$patientName a las $timeStr\nMotivo: ${appointment.reason}',
      );

      await notification.show();
    } catch (e) {
      debugPrint('AppointmentNotificationService._showNotification error: $e');
    }
  }
}
