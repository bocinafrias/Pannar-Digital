import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/data_notification_service.dart';

class AppointmentListScreen extends StatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  late final DataNotificationService _notificationService;
  List<AppointmentModel> _appointments = [];
  List<AppointmentModel> _filteredAppointments = [];
  Map<String, PatientModel> _patientsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _searchController.addListener(_filterAppointments);
    // Guardamos la referencia para que el dispose use la MISMA instancia.
    _notificationService = context.read<DataNotificationService>();
    _notificationService.addListener(_loadAppointments);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAppointments);
    _searchController.dispose();
    _notificationService.removeListener(_loadAppointments);
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUserModel;

      // Si es psicólogo, solo cargar sus citas
      // Si es admin, cargar todas las citas
      String? psychologistId;
      String? psychologistName;
      if (currentUser != null && currentUser.role != UserRole.admin) {
        psychologistId = currentUser.id;
        psychologistName =
            currentUser.name; // También pasar el nombre para búsqueda flexible
      }

      final appointments = await _db.getAppointments(
        psychologistId: psychologistId,
        psychologistName: psychologistName,
      );
      final patients = await _db.getPatients(psychologistId: psychologistId);

      // Crear mapa de pacientes para acceso rápido
      final patientsMap = <String, PatientModel>{};
      for (var patient in patients) {
        patientsMap[patient.id] = patient;
      }

      setState(() {
        _appointments = appointments;
        _filteredAppointments = appointments;
        _patientsMap = patientsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar citas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterAppointments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredAppointments = _appointments;
      } else {
        _filteredAppointments = _appointments.where((appointment) {
          final patient = _patientsMap[appointment.patientId];
          final patientName = patient?.name.toLowerCase() ?? '';
          final reason = appointment.reason.toLowerCase();
          final dateStr = DateFormat('dd/MM/yyyy HH:mm', 'es')
              .format(appointment.dateTime)
              .toLowerCase();
          return patientName.contains(query) ||
              reason.contains(query) ||
              dateStr.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _deleteAppointment(AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta cita? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteAppointment(appointment.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Cita eliminada exitosamente'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        _loadAppointments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar cita: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
                  // Content
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar citas...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  context.go('/appointment/new');
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Nueva Cita'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A5F),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _filteredAppointments.isEmpty
                                  ? const Center(
                                      child: Text('No hay citas registradas'),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      itemCount: _filteredAppointments.length,
                                      itemBuilder: (context, index) {
                                        final appointment =
                                            _filteredAppointments[index];
                                        final patient =
                                            _patientsMap[appointment.patientId];
                                        final dateFormat = DateFormat(
                                          'dd/MM/yyyy HH:mm',
                                          'es',
                                        );

                                        return Card(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: _getStatusColor(
                                                  appointment.status),
                                              child: Text(
                                                appointment.dateTime.hour
                                                    .toString()
                                                    .padLeft(2, '0'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              patient?.name ??
                                                  'Paciente desconocido',
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  dateFormat.format(
                                                    appointment.dateTime,
                                                  ),
                                                ),
                                                Text(appointment.reason),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(
                                                                appointment
                                                                    .status)
                                                            .withValues(alpha: 0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Text(
                                                        _getStatusText(
                                                            appointment.status),
                                                        style: TextStyle(
                                                          color:
                                                              _getStatusColor(
                                                                  appointment
                                                                      .status),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            trailing: PopupMenuButton<String>(
                                              onSelected: (value) async {
                                                if (value == 'edit') {
                                                  final router =
                                                      GoRouter.of(context);
                                                  await Future.delayed(
                                                    const Duration(
                                                      milliseconds: 100,
                                                    ),
                                                  );
                                                  router.go(
                                                    '/appointment/new',
                                                    extra: appointment,
                                                  );
                                                } else if (value == 'delete') {
                                                  _deleteAppointment(
                                                      appointment);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit,
                                                          size: 20),
                                                      SizedBox(width: 8),
                                                      Text('Editar'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete,
                                                          size: 20,
                                                          color: Colors.red),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Eliminar',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onTap: () async {
                                              final router =
                                                  GoRouter.of(context);
                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 100,
                                                ),
                                              );
                                              router.go(
                                                '/appointment/new',
                                                extra: appointment,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
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
