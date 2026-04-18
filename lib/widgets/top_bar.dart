import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/data_notification_service.dart';
import '../models/user_model.dart';
import 'package:provider/provider.dart';

class TopBar extends StatefulWidget {
  final String userName;

  const TopBar({super.key, required this.userName});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final _db = DatabaseService();
  late final DataNotificationService _notificationService;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    // Capturamos la referencia sincrónicamente para que el dispose use
    // la MISMA instancia aunque el widget se desmonte antes del primer frame.
    _notificationService = context.read<DataNotificationService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadNotificationCount();
      _notificationService.addListener(_loadNotificationCount);
    });
  }

  @override
  void dispose() {
    // removeListener es idempotente: seguro aunque nunca se haya agregado.
    _notificationService.removeListener(_loadNotificationCount);
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    if (!mounted) return;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUserModel;

      // Si es admin, pasar null para obtener todas las citas
      // Si es psicólogo, pasar su ID para obtener solo sus citas
      String? psychologistId;
      if (currentUser != null && currentUser.role != UserRole.admin) {
        psychologistId = currentUser.id;
      }

      final count = await _db.getTodayAppointmentsCount(
        psychologistId: psychologistId,
      );
      if (!mounted) return;
      setState(() {
        _notificationCount = count;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notificationCount = 0;
      });
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${now.day} de ${months[now.month - 1]}, ${now.year}';
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notificaciones'),
        content: _notificationCount == 0
            ? const Text('No tienes notificaciones pendientes.')
            : Text(
                'Tienes $_notificationCount ${_notificationCount == 1 ? 'cita programada' : 'citas programadas'} para hoy.',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cierre de sesión'),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Cerrar diálogo de confirmación
              await _logout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      // Cerrar sesión y limpiar completamente
      await authService.signOut(clearLocalSession: true);
      // Navegar al login inmediatamente - no esperar delay
      if (context.mounted) {
        context.go('/login');
      }
    } catch (e) {
      // Aún navegar al login aunque haya error
      if (context.mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isDashboard = currentRoute == '/dashboard';

    return Container(
      height: 100,
      color: const Color(0xFF1E3A5F),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Botón de retroceso (solo si no estamos en dashboard)
              if (!isDashboard) ...[
                IconButton(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: 'Volver al Dashboard',
                ),
              ],
            ],
          ),
          Row(
            children: [
              // Notification Icon (clickeable)
              GestureDetector(
                onTap: _showNotificationsDialog,
                child: Stack(
                  children: [
                    const Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 28,
                    ),
                    if (_notificationCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _notificationCount > 9
                                ? '9+'
                                : '$_notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // User Profile con menú desplegable
              PopupMenuButton<String>(
                offset: const Offset(0, 60),
                onSelected: (value) {
                  if (value == 'logout') {
                    _showLogoutConfirmation(context);
                  }
                },
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            const Text(
                              'Hoy',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getFormattedDate(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                  ],
                ),
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Cerrar sesión',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
