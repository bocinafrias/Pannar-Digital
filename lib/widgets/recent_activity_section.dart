import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/data_notification_service.dart';

class RecentActivitySection extends StatefulWidget {
  final String? psychologistId;
  final String? psychologistName;
  
  const RecentActivitySection({
    super.key,
    this.psychologistId,
    this.psychologistName,
  });

  @override
  State<RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<RecentActivitySection> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentActivity();
    // Escuchar cambios en los datos
    final notificationService =
        Provider.of<DataNotificationService>(context, listen: false);
    notificationService.addListener(_loadRecentActivity);
  }

  @override
  void dispose() {
    // Remover listener para evitar memory leaks
    final notificationService =
        Provider.of<DataNotificationService>(context, listen: false);
    notificationService.removeListener(_loadRecentActivity);
    super.dispose();
  }

  Future<void> _loadRecentActivity() async {
    setState(() => _isLoading = true);
    try {
      final activities = await _db.getRecentActivity(
        limit: 4,
        psychologistId: widget.psychologistId,
        psychologistName: widget.psychologistName,
      );
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error cargando actividad reciente: $e');
    }
  }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Actividad Reciente',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadRecentActivity,
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_activities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No hay actividad reciente',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._activities.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              final iconName = activity['iconName'] as String;
              final iconColorName = activity['iconColorName'] as String;

              IconData icon;
              Color iconColor;

              // Mapear nombres a iconos
              switch (iconName) {
                case 'person_add':
                  icon = Icons.person_add;
                  break;
                case 'check_circle':
                  icon = Icons.check_circle;
                  break;
                case 'cancel':
                  icon = Icons.cancel;
                  break;
                default:
                  icon = Icons.info;
              }

              // Mapear nombres a colores
              switch (iconColorName) {
                case 'green':
                  iconColor = Colors.green;
                  break;
                case 'blue':
                  iconColor = Colors.blue;
                  break;
                case 'red':
                  iconColor = Colors.red;
                  break;
                default:
                  iconColor = Colors.grey;
              }

              return Column(
                children: [
                  if (index > 0) const SizedBox(height: 16),
                  _ActivityItem(
                    icon: icon,
                    iconColor: iconColor,
                    title: activity['title'] as String,
                    subtitle: activity['subtitle'] as String,
                  ),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
