import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'report_generator_dialog.dart';

class WelcomeSection extends StatelessWidget {
  final String userName;
  final int todayAppointments;
  final String? userGender; // 'M', 'F', 'O' o null

  const WelcomeSection({
    super.key,
    required this.userName,
    this.todayAppointments = 0,
    this.userGender,
  });

  String _getWelcomeMessage() {
    // Detectar género del nombre o usar el campo gender si está disponible
    final nameLower = userName.toLowerCase();

    // Nombres comunes femeninos en español
    final femaleNames = [
      'maria',
      'ana',
      'carmen',
      'laura',
      'patricia',
      'marta',
      'cristina',
      'elena',
      'isabel',
      'monica',
      'andrea',
      'sofia',
      'natalia',
      'claudia',
      'diana',
      'paula',
      'lucia',
      'sara'
    ];

    // Nombres comunes masculinos en español
    final maleNames = [
      'juan',
      'carlos',
      'jose',
      'luis',
      'miguel',
      'pedro',
      'david',
      'antonio',
      'francisco',
      'manuel',
      'javier',
      'rafael',
      'daniel',
      'pablo',
      'alejandro',
      'roberto',
      'fernando',
      'ricardo'
    ];

    // Si hay un campo gender, usarlo
    if (userGender != null) {
      if (userGender!.toUpperCase() == 'F' ||
          userGender!.toLowerCase().contains('fem')) {
        return 'Hola, $userName';
      } else if (userGender!.toUpperCase() == 'M' ||
          userGender!.toLowerCase().contains('masc')) {
        return 'Hola, $userName';
      }
    }

    // Intentar detectar del nombre
    final firstName = nameLower.split(' ').first;
    if (femaleNames.any((name) => firstName.contains(name))) {
      return 'Hola, $userName';
    } else if (maleNames.any((name) => firstName.contains(name))) {
      return 'Hola, $userName';
    }

    // Por defecto, usar forma neutra
    return 'Hola, $userName';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getWelcomeMessage(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tienes $todayAppointments citas programadas para hoy',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        // Action Buttons
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _ActionButton(
              icon: Icons.add,
              secondaryIcon: Icons.person,
              label: 'Agendar Cita',
              color: Colors.blue,
              onTap: () => context.go('/appointment/new'),
            ),
            _ActionButton(
              icon: Icons.add,
              secondaryIcon: Icons.person_add,
              label: 'Registrar Paciente',
              color: Colors.green,
              onTap: () => context.go('/patient/new'),
            ),
            _ActionButton(
              icon: Icons.description,
              label: 'Generar Reporte',
              color: Colors.orange,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const ReportGeneratorDialog(),
                );
              },
            ),
            _ActionButton(
              icon: Icons.search,
              label: 'Buscar Paciente',
              color: Colors.blue,
              onTap: () => context.go('/patients'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final IconData? secondaryIcon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.secondaryIcon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          if (secondaryIcon != null) ...[
            const SizedBox(width: 4),
            Icon(secondaryIcon, size: 18),
          ],
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
