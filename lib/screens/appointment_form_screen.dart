import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/appointment_model.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';

class AppointmentFormScreen extends StatefulWidget {
  final AppointmentModel? appointment;

  const AppointmentFormScreen({super.key, this.appointment});

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  String? _selectedPatientId;
  final _psychologistController =
      TextEditingController(); // Campo de texto libre para psicólogo
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  AppointmentStatus _status = AppointmentStatus.scheduled;
  bool? _attended; // null = no registrado, true = asistió, false = no asistió
  List<PatientModel> _patients = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    if (widget.appointment != null) {
      _loadAppointmentData();
    } else {
      // Si es una cita nueva y el usuario es psicólogo, rellenar automáticamente su nombre
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUserModel;
      if (currentUser != null && currentUser.role == UserRole.psychologist) {
        _psychologistController.text = currentUser.name;
      }
    }
  }

  @override
  void dispose() {
    _psychologistController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUserModel;

    // Si es psicólogo, solo cargar sus pacientes
    // Si es admin, cargar todos los pacientes
    String? psychologistId;
    if (currentUser != null && currentUser.role == UserRole.psychologist) {
      psychologistId = currentUser.id;
    }

    final patients = await _db.getPatients(psychologistId: psychologistId);
    setState(() => _patients = patients);
  }

  Future<void> _loadAppointmentData() async {
    final appointment = widget.appointment!;
    _selectedDate = appointment.dateTime;
    _selectedTime = TimeOfDay.fromDateTime(appointment.dateTime);
    _reasonController.text = appointment.reason;
    _notesController.text = appointment.notes ?? '';
    _status = appointment.status;
    _attended = appointment.attended;

    // Cargar paciente seleccionado
    if (appointment.patientId.isNotEmpty) {
      setState(() => _selectedPatientId = appointment.patientId);
    }

    // Cargar psicólogo responsable
    // Si el psychologist_id es un ID (UUID), intentar obtener el nombre
    // Si no, mostrar el valor tal cual (puede ser nombre de citas antiguas)
    if (appointment.psychologistId.isNotEmpty) {
      final authService = context.read<AuthService>();
      try {
        final users = await authService.getUsers();
        final user = users
            .where(
              (u) => u.id == appointment.psychologistId,
            )
            .firstOrNull;
        // Si encontramos el usuario, mostrar su nombre, sino mostrar el valor original
        _psychologistController.text = user?.name ?? appointment.psychologistId;
      } catch (e) {
        // Si hay error, mostrar el valor original
        _psychologistController.text = appointment.psychologistId;
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate() ||
        _selectedPatientId == null ||
        _selectedPatientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Prevenir múltiples clics
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Validar duplicados (solo para nuevas citas)
      if (widget.appointment == null) {
        final existingAppointments = await _db.getAppointments();
        final duplicate = existingAppointments.any((a) =>
            a.patientId == _selectedPatientId &&
            a.dateTime.year == dateTime.year &&
            a.dateTime.month == dateTime.month &&
            a.dateTime.day == dateTime.day &&
            a.dateTime.hour == dateTime.hour &&
            a.dateTime.minute == dateTime.minute);

        if (duplicate) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ya existe una cita para este paciente a la misma fecha y hora',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      // Si es psicólogo, usar su ID para el psychologist_id
      // El campo de texto puede mostrar el nombre, pero guardamos el ID
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUserModel;
      String psychologistId;

      // Si es psicólogo, usar su ID (no el nombre del campo de texto)
      if (currentUser != null && currentUser.role == UserRole.psychologist) {
        psychologistId = currentUser.id;
      } else {
        // Si es admin o el campo tiene texto, usar el valor del campo
        // (puede ser nombre o ID, se buscará flexiblemente)
        psychologistId = _psychologistController.text.trim();
        if (psychologistId.isEmpty) {
          // Si está vacío y es admin, usar un valor por defecto o dejar vacío
          psychologistId = '';
        }
      }

      final appointment = AppointmentModel(
        id: widget.appointment?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: _selectedPatientId!,
        psychologistId: psychologistId,
        dateTime: dateTime,
        reason: _reasonController.text,
        status: _status,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        attended: _attended,
        createdAt: widget.appointment?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.insertAppointment(appointment);

      if (!mounted) return;

      // Determinar el mensaje según si es edición o creación
      final isEditing = widget.appointment != null;

      // Mostrar diálogo de éxito en el centro
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  isEditing
                      ? 'Cita actualizada exitosamente'
                      : 'Cita agendada exitosamente',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop(); // Cerrar diálogo
                    if (mounted) {
                      context.pop(); // Cerrar formulario
                      // Delay para asegurar que la base de datos se actualice y la notificación se propague
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (mounted) {
                        // Redirigir al calendario - esto forzará una recarga
                        context.go('/calendar');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.appointment == null
                                  ? 'Nueva Cita'
                                  : 'Editar Cita',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Selección de paciente
                            DropdownButtonFormField<String>(
                              value: _selectedPatientId,
                              decoration: const InputDecoration(
                                labelText: 'Paciente *',
                                border: OutlineInputBorder(),
                              ),
                              items: _patients.map((patient) {
                                return DropdownMenuItem(
                                  value: patient.id,
                                  child: Text(patient.name),
                                );
                              }).toList(),
                              onChanged: (patientId) {
                                setState(() => _selectedPatientId = patientId);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Selecciona un paciente';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Campo de texto libre para psicólogo responsable
                            TextFormField(
                              controller: _psychologistController,
                              decoration: const InputDecoration(
                                labelText: 'Psicólogo responsable',
                                hintText:
                                    'Ingrese el nombre del psicólogo responsable',
                                border: OutlineInputBorder(),
                              ),
                              // No es obligatorio, puede estar vacío
                            ),
                            const SizedBox(height: 16),
                            // Fecha
                            ListTile(
                              title: const Text('Fecha'),
                              subtitle: Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectDate,
                            ),
                            const SizedBox(height: 8),
                            // Hora
                            ListTile(
                              title: const Text('Hora'),
                              subtitle: Text(_selectedTime.format(context)),
                              trailing: const Icon(Icons.access_time),
                              onTap: _selectTime,
                            ),
                            const SizedBox(height: 16),
                            // Motivo
                            TextFormField(
                              controller: _reasonController,
                              decoration: const InputDecoration(
                                labelText: 'Motivo de consulta *',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa el motivo de consulta';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Estado
                            DropdownButtonFormField<AppointmentStatus>(
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Estado',
                                border: OutlineInputBorder(),
                              ),
                              items: AppointmentStatus.values.map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(_getStatusText(status)),
                                );
                              }).toList(),
                              onChanged: (status) {
                                setState(() => _status =
                                    status ?? AppointmentStatus.scheduled);
                              },
                            ),
                            const SizedBox(height: 16),
                            // Notas
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notas adicionales',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 24),
                            // Botón guardar
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveAppointment,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: const Color(0xFF1E3A5F),
                                  foregroundColor: Colors.white,
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Guardar Cita',
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
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
}
