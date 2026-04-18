import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/patient_model.dart';
import '../models/appointment_model.dart';
import '../services/database_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../services/data_notification_service.dart';

class ClinicalHistoryScreen extends StatefulWidget {
  const ClinicalHistoryScreen({super.key});

  @override
  State<ClinicalHistoryScreen> createState() => _ClinicalHistoryScreenState();
}

class _ClinicalHistoryScreenState extends State<ClinicalHistoryScreen> {
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  late final DataNotificationService _notificationService;
  List<PatientModel> _patients = [];
  Map<String, List<AppointmentModel>> _patientAppointments = {};
  Map<String, String> _psychologistNames = {}; // id → nombre
  List<PatientModel> _filteredPatients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClinicalHistory();
    _searchController.addListener(_filterPatients);
    // Guardamos la referencia para que el dispose use la MISMA instancia.
    _notificationService = context.read<DataNotificationService>();
    _notificationService.addListener(_loadClinicalHistory);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notificationService.removeListener(_loadClinicalHistory);
    super.dispose();
  }

  Future<void> _loadClinicalHistory() async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUserModel;

      // Si es psicólogo, solo cargar sus pacientes
      // Si es admin, cargar todos los pacientes
      String? psychologistId;
      if (currentUser != null && currentUser.role != UserRole.admin) {
        psychologistId = currentUser.id;
      }

      // Cargar pacientes
      final patients = await _db.getPatients(psychologistId: psychologistId);
      
      // Cargar todas las citas completadas
      final allAppointments = await _db.getAppointments();
      final completedAppointments = allAppointments
          .where((apt) =>
              apt.status == AppointmentStatus.completed &&
              apt.attended == true)
          .toList();

      // Organizar citas por paciente
      final appointmentsMap = <String, List<AppointmentModel>>{};
      for (var appointment in completedAppointments) {
        if (!appointmentsMap.containsKey(appointment.patientId)) {
          appointmentsMap[appointment.patientId] = [];
        }
        appointmentsMap[appointment.patientId]!.add(appointment);
      }

      // Ordenar citas por fecha (más recientes primero)
      appointmentsMap.forEach((patientId, appointments) {
        appointments.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      });

      // Cargar mapa de nombres de psicólogos
      final users = await authService.getUsers();
      final nameMap = {for (final u in users) u.id: u.name};

      setState(() {
        _patients = patients;
        _patientAppointments = appointmentsMap;
        _psychologistNames = nameMap;
        _filteredPatients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = _patients;
      } else {
        _filteredPatients = _patients.where((patient) {
          return patient.name.toLowerCase().contains(query) ||
              (patient.email?.toLowerCase().contains(query) ?? false) ||
              (patient.phone?.contains(query) ?? false);
        }).toList();
      }
    });
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
                                    hintText: 'Buscar en historial clínico...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _filteredPatients.isEmpty
                                  ? const Center(
                                      child: Text('No hay pacientes registrados'),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      itemCount: _filteredPatients.length,
                                      itemBuilder: (context, index) {
                                        final patient = _filteredPatients[index];
                                        final appointments =
                                            _patientAppointments[patient.id] ??
                                                [];
                                        return _PatientHistoryCard(
                                          patient: patient,
                                          appointments: appointments,
                                          psychologistNames: _psychologistNames,
                                          onTap: () {
                                            context.go('/patient/${patient.id}');
                                          },
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

class _PatientHistoryCard extends StatelessWidget {
  final PatientModel patient;
  final List<AppointmentModel> appointments;
  final Map<String, String> psychologistNames;
  final VoidCallback onTap;

  const _PatientHistoryCard({
    required this.patient,
    required this.appointments,
    required this.psychologistNames,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'es');
    final timeFormat = DateFormat('HH:mm', 'es');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF1E3A5F),
                    child: Text(
                      patient.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        if (patient.phone != null)
                          Text(
                            patient.phone!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: appointments.isEmpty
                          ? Colors.grey[300]
                          : const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${appointments.length} ${appointments.length == 1 ? 'sesión' : 'sesiones'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: appointments.isEmpty
                            ? Colors.grey[600]
                            : const Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                ],
              ),
              if (appointments.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Historial de Sesiones:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...appointments.take(5).map((appointment) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${dateFormat.format(appointment.dateTime)} - ${timeFormat.format(appointment.dateTime)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        if (appointment.psychologistId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  psychologistNames[appointment.psychologistId] ??
                                      appointment.psychologistId,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (appointment.reason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Motivo: ${appointment.reason}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        if (appointment.notes != null &&
                            appointment.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              appointment.notes!,
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                if (appointments.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Y ${appointments.length - 5} sesión${appointments.length - 5 == 1 ? '' : 'es'} más...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'No hay sesiones registradas',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}










