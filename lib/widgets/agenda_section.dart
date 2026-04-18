import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/appointment_model.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class AgendaSection extends StatelessWidget {
  final List<AppointmentModel> appointments;

  const AgendaSection({super.key, required this.appointments});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agenda de Hoy',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 16),
          if (appointments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No hay citas programadas para hoy',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...appointments.asMap().entries.map((entry) {
              final index = entry.key;
              final appointment = entry.value;

              final startTime =
                  '${appointment.dateTime.hour.toString().padLeft(2, '0')}:${appointment.dateTime.minute.toString().padLeft(2, '0')}';
              final endTime =
                  '${(appointment.dateTime.hour + 1).toString().padLeft(2, '0')}:${appointment.dateTime.minute.toString().padLeft(2, '0')}';

              final isPast = appointment.dateTime.isBefore(DateTime.now());

              return FutureBuilder(
                future: DatabaseService().getPatientById(appointment.patientId),
                builder: (context, snapshot) {
                  final patientName = snapshot.hasData && snapshot.data != null
                      ? snapshot.data!.name
                      : 'Paciente ${appointment.patientId.substring(0, 8)}';

                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 24),
                      _AgendaItem(
                        name: patientName,
                        type: appointment.reason,
                        time: '$startTime - $endTime',
                        appointment: appointment,
                        isPast: isPast,
                      ),
                    ],
                  );
                },
              );
            }).toList(),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/calendar'),
            child: const Text(
              'Ver todas las citas',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaItem extends StatelessWidget {
  final String name;
  final String type;
  final String time;
  final AppointmentModel appointment;
  final bool isPast;

  const _AgendaItem({
    required this.name,
    required this.type,
    required this.time,
    required this.appointment,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        _showAppointmentDetails(context);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                      ),
                      // Indicador de asistencia para citas pasadas
                      if (isPast ||
                          appointment.status == AppointmentStatus.completed)
                        Icon(
                          appointment.attended == true
                              ? Icons.check_circle
                              : appointment.attended == false
                                  ? Icons.cancel
                                  : Icons.help_outline,
                          size: 20,
                          color: appointment.attended == true
                              ? Colors.green
                              : appointment.attended == false
                                  ? Colors.red
                                  : Colors.orange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isPast ||
                          appointment.status == AppointmentStatus.completed)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            appointment.attended == true
                                ? '• Completada'
                                : appointment.attended == false
                                    ? '• Cancelada'
                                    : '• Sin registrar',
                            style: TextStyle(
                              fontSize: 11,
                              color: appointment.attended == true
                                  ? Colors.green
                                  : appointment.attended == false
                                      ? Colors.red
                                      : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointmentDetails(BuildContext context) async {
    final db = DatabaseService();
    final patient = await db.getPatientById(appointment.patientId);

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
            onPressed: () {
              Navigator.of(context).pop();
              // Navegar a editar la cita
              context.go(
                '/appointment/new',
                extra: appointment,
              );
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

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return Colors.blue;
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.cancelled:
        return Colors.red;
      case AppointmentStatus.rescheduled:
        return Colors.orange;
    }
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
