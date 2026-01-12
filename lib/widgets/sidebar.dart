import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF1E3A5F), // Dark blue
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo (clickeable para volver al dashboard)
          InkWell(
            onTap: () => context.go('/dashboard'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dashboard,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'PANNAR Digital',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(
            color: Colors.white24,
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 8),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _NavItem(
                  icon: Icons.dashboard,
                  title: 'Inicio',
                  route: '/dashboard',
                ),
                _NavItem(
                  icon: Icons.calendar_today,
                  title: 'Calendario',
                  route: '/calendar',
                ),
                _NavItem(
                  icon: Icons.people,
                  title: 'Pacientes',
                  route: '/patients',
                ),
                _NavItem(
                  icon: Icons.event_note,
                  title: 'Citas',
                  route: '/appointments',
                ),
                _NavItem(
                  icon: Icons.description,
                  title: 'Historial Clínico',
                  route: '/clinical-history',
                ),
                _NavItem(
                  icon: Icons.bar_chart,
                  title: 'Reportes',
                  route: '/reports',
                ),
                const Divider(
                  color: Colors.white24,
                  height: 32,
                  thickness: 1,
                ),
                _NavItem(
                  icon: Icons.settings,
                  title: 'Configuración',
                  route: '/dashboard',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;

  const _NavItem({
    required this.icon,
    required this.title,
    required this.route,
  });

  bool _isActive(BuildContext context) {
    try {
      final currentRoute = GoRouterState.of(context).uri.path;
      return currentRoute == route;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isActive(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2E5A8F) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        onTap: () => context.go(route),
      ),
    );
  }
}
