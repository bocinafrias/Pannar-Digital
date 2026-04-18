import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/data_notification_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String? _selectedPsychologistId;
  List<AppointmentModel> _appointments = [];
  List<UserModel> _psychologists = [];
  Map<String, String> _psychologistNames = {}; // id → nombre
  late final DataNotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    // Inicializar locale español
    initializeDateFormatting('es', null).then((_) {
      if (mounted) setState(() {}); // Reconstruir después de cargar locale
    });
    _loadPsychologists();
    _loadAppointments();
    // Guardamos la referencia para que el dispose use la MISMA instancia.
    _notificationService = context.read<DataNotificationService>();
    _notificationService.addListener(_loadAppointments);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_loadAppointments);
    super.dispose();
  }

  /// Carga la lista de psicólogos y construye el mapa id→nombre para todos los usuarios.
  Future<void> _loadPsychologists() async {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUserModel;

    final users = await authService.getUsers();
    final nameMap = {for (final u in users) u.id: u.name};

    if (!mounted) return;
    setState(() {
      // El dropdown de filtro solo es relevante para admins
      if (currentUser?.role == UserRole.admin) {
        _psychologists =
            users.where((u) => u.role == UserRole.psychologist).toList();
      }
      // Siempre popular el mapa de nombres para resolución en diálogos
      _psychologistNames = nameMap;
    });
  }

  /// Resuelve el campo psychologistId a un nombre legible.
  /// El campo puede contener un UUID real o un nombre directo (datos legacy).
  String _getPsychologistName(String psychologistId) {
    if (_psychologistNames.containsKey(psychologistId)) {
      return _psychologistNames[psychologistId]!;
    }
    // Si no está en el mapa, el campo ya es un nombre (dato legacy)
    return psychologistId;
  }

  Future<void> _loadAppointments() async {
    final db = DatabaseService();
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUserModel;

    // Si es psicólogo, solo cargar sus citas (usar nombre para búsqueda flexible)
    // Si es admin, cargar todas las citas (o filtradas por _selectedPsychologistId si se seleccionó uno)
    String? psychologistId;
    String? psychologistName;
    if (currentUser != null && currentUser.role != UserRole.admin) {
      psychologistId = currentUser.id;
      psychologistName =
          currentUser.name; // Usar nombre para búsqueda en campo de texto libre
    } else {
      psychologistId = _selectedPsychologistId;
      // Si el admin selecciona un psicólogo, podríamos buscar por nombre también
      // Por ahora, solo usar ID para admins
    }

    final appointments = await db.getAppointments(
      psychologistId: psychologistId,
      psychologistName: psychologistName,
    );
    if (!mounted) return;
    setState(() => _appointments = appointments);
  }

  List<AppointmentModel> _getAppointmentsForDay(DateTime day) {
    return _appointments.where((appointment) {
      final appointmentDate = appointment.dateTime;
      return appointmentDate.year == day.year &&
          appointmentDate.month == day.month &&
          appointmentDate.day == day.day;
    }).toList();
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUserModel;
    final userName = currentUser?.name ?? 'Usuario';
    final isAdmin = currentUser?.role == UserRole.admin;

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
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Fila superior: filtro (admin) + botones de formato
                          Row(
                            children: [
                              // Dropdown filtro por psicólogo (solo admin)
                              if (isAdmin) ...[
                                const Icon(
                                  Icons.person_search_outlined,
                                  size: 20,
                                  color: Color(0xFF1E3A5F),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String?>(
                                  value: _selectedPsychologistId,
                                  hint: const Text('Todos los psicólogos'),
                                  underline: Container(
                                    height: 2,
                                    color: const Color(0xFF1E3A5F),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Todos los psicólogos'),
                                    ),
                                    ..._psychologists.map(
                                      (p) => DropdownMenuItem<String?>(
                                        value: p.id,
                                        child: Text(p.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                        () => _selectedPsychologistId = value);
                                    _loadAppointments();
                                  },
                                ),
                                const Spacer(),
                              ] else
                                const Spacer(),
                              // Botones de formato de vista
                              _buildFormatButton(
                                'Mes',
                                CalendarFormat.month,
                                _calendarFormat == CalendarFormat.month,
                              ),
                              const SizedBox(width: 8),
                              _buildFormatButton(
                                '2 Semanas',
                                CalendarFormat.twoWeeks,
                                _calendarFormat == CalendarFormat.twoWeeks,
                              ),
                              const SizedBox(width: 8),
                              _buildFormatButton(
                                'Semana',
                                CalendarFormat.week,
                                _calendarFormat == CalendarFormat.week,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TableCalendar<AppointmentModel>(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            calendarFormat: _calendarFormat,
                            eventLoader: _getAppointmentsForDay,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            locale: 'es',
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                            ),
                            daysOfWeekStyle: const DaysOfWeekStyle(
                              weekdayStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                              weekendStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) {
                              setState(() => _calendarFormat = format);
                            },
                            onPageChanged: (focusedDay) {
                              setState(() {
                                _focusedDay = focusedDay;
                              });
                            },
                            calendarStyle: const CalendarStyle(
                              todayDecoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: Color(0xFF1E3A5F),
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              weekendTextStyle: TextStyle(
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                          ),
                          const Divider(),
                          Expanded(
                            child: _buildAppointmentsList(isAdmin: isAdmin),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/appointment/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAppointmentsList({bool isAdmin = false}) {
    final dayAppointments = _getAppointmentsForDay(_selectedDay);

    if (dayAppointments.isEmpty) {
      return const Center(
        child: Text('No hay citas programadas para este día'),
      );
    }

    return ListView.builder(
      itemCount: dayAppointments.length,
      itemBuilder: (context, index) {
        final appointment = dayAppointments[index];
        final isPast = appointment.dateTime.isBefore(DateTime.now());
        final psychologistName =
            _getPsychologistName(appointment.psychologistId);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(appointment.status),
              child: Text(
                appointment.dateTime.hour.toString().padLeft(2, '0'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(appointment.reason),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${appointment.dateTime.hour.toString().padLeft(2, '0')}:${appointment.dateTime.minute.toString().padLeft(2, '0')}',
                ),
                if (isAdmin)
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 13,
                        color: Color(0xFF1E3A5F),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        psychologistName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A5F),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (isPast || appointment.status == AppointmentStatus.completed)
                  Row(
                    children: [
                      Icon(
                        appointment.attended == true
                            ? Icons.check_circle
                            : appointment.attended == false
                                ? Icons.cancel
                                : Icons.help_outline,
                        size: 16,
                        color: appointment.attended == true
                            ? Colors.green
                            : appointment.attended == false
                                ? Colors.red
                                : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        appointment.attended == true
                            ? 'Completada'
                            : appointment.attended == false
                                ? 'Cancelada'
                                : 'Sin registrar',
                        style: TextStyle(
                          fontSize: 12,
                          color: appointment.attended == true
                              ? Colors.green
                              : appointment.attended == false
                                  ? Colors.red
                                  : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPast || appointment.status == AppointmentStatus.completed)
                  if (appointment.attended == null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        final db = DatabaseService();
                        if (value == 'attended') {
                          await db.updateAppointmentAttendance(
                            appointment.id,
                            true,
                          );
                        } else if (value == 'not_attended') {
                          await db.updateAppointmentAttendance(
                            appointment.id,
                            false,
                          );
                        }
                        _loadAppointments();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'attended',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Marcar como completada'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'not_attended',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Marcar como cancelada'),
                            ],
                          ),
                        ),
                      ],
                    ),
                const SizedBox(width: 8),
                _getStatusIcon(appointment.status),
              ],
            ),
            onTap: () => _showAppointmentDetails(context, appointment),
          ),
        );
      },
    );
  }

  Widget _getStatusIcon(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case AppointmentStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.red);
      case AppointmentStatus.rescheduled:
        return const Icon(Icons.schedule, color: Colors.orange);
      default:
        return const Icon(Icons.event, color: Colors.blue);
    }
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.cancelled:
        return Colors.red;
      case AppointmentStatus.rescheduled:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _showAppointmentDetails(
      BuildContext context, AppointmentModel appointment) async {
    final db = DatabaseService();
    final authService = context.read<AuthService>();

    // Cargar paciente y nombre de psicólogo en paralelo
    final patientFuture = db.getPatientById(appointment.patientId);
    final psychNameFuture = appointment.psychologistId.isNotEmpty
        ? authService.getUserNameById(appointment.psychologistId)
        : Future.value('');

    final patient = await patientFuture;
    final resolvedPsychName = await psychNameFuture;
    final isPast = appointment.dateTime.isBefore(DateTime.now());

    if (!context.mounted) return;

    final dateFormat = DateFormat('EEEE, d \'de\' MMMM \'de\' y', 'es');
    final timeFormat = DateFormat('HH:mm', 'es');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Detalles de la Cita',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                icon: Icons.person,
                label: 'Paciente:',
                value: patient?.name ??
                    'Paciente ${appointment.patientId.substring(0, 8)}',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.calendar_today,
                label: 'Fecha:',
                value: dateFormat.format(appointment.dateTime),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.access_time,
                label: 'Hora:',
                value: timeFormat.format(appointment.dateTime),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.description,
                label: 'Motivo:',
                value: appointment.reason,
              ),
              if (appointment.psychologistId.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Psicólogo responsable:',
                  value: resolvedPsychName.isNotEmpty
                      ? resolvedPsychName
                      : _getPsychologistName(appointment.psychologistId),
                ),
              ],
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.info,
                label: 'Estado:',
                value: _getStatusText(appointment.status),
                valueColor: _getStatusColor(appointment.status),
              ),
              if (isPast ||
                  appointment.status == AppointmentStatus.completed) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: appointment.attended == true
                      ? Icons.check_circle
                      : appointment.attended == false
                          ? Icons.cancel
                          : Icons.help_outline,
                  label: 'Estado:',
                  value: appointment.attended == true
                      ? 'Completada'
                      : appointment.attended == false
                          ? 'Cancelada'
                          : 'Sin registrar',
                  valueColor: appointment.attended == true
                      ? Colors.green
                      : appointment.attended == false
                          ? Colors.red
                          : Colors.orange,
                ),
              ],
              if (appointment.notes != null &&
                  appointment.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Notas:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.notes!,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // Capturamos router antes del await para no usar el
              // BuildContext del diálogo después del async gap.
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              // Cargar la cita completa y navegar al formulario de edición
              final fullAppointment =
                  await db.getAppointmentById(appointment.id);
              if (fullAppointment != null) {
                router.go(
                  '/appointment/new',
                  extra: fullAppointment,
                );
                // Recargar citas después de un breve delay
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _loadAppointments();
                  }
                });
              }
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Editar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return 'Programada';
      case AppointmentStatus.completed:
        return 'Completada';
      case AppointmentStatus.cancelled:
        return 'Cancelada';
      case AppointmentStatus.rescheduled:
        return 'Reprogramada';
    }
  }

  Widget _buildFormatButton(
    String text,
    CalendarFormat format,
    bool isSelected,
  ) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _calendarFormat = format;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(text),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valueColor ?? Colors.black87,
                    fontWeight: valueColor != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
