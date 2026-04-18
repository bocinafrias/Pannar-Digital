import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/data_notification_service.dart';

class WeeklySummarySection extends StatefulWidget {
  final String? psychologistId;
  final String? psychologistName;
  
  const WeeklySummarySection({
    super.key,
    this.psychologistId,
    this.psychologistName,
  });

  @override
  State<WeeklySummarySection> createState() => _WeeklySummarySectionState();
}

class _WeeklySummarySectionState extends State<WeeklySummarySection> {
  final _db = DatabaseService();
  late final DataNotificationService _notificationService;
  Map<String, int> _genderStats = {
    'male': 0,
    'female': 0,
    'other': 0,
    'total': 0
  };
  Map<String, int> _statusCounts = {
    'completed': 0,
    'pending': 0,
    'cancelled': 0
  };

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    // Guardamos la referencia para que el dispose use la MISMA instancia.
    _notificationService = context.read<DataNotificationService>();
    _notificationService.addListener(_loadStatistics);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_loadStatistics);
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      final genderStats = await _db.getGenderStatistics(psychologistId: widget.psychologistId);
      final statusCounts = await _db.getAppointmentStatusCounts(
        psychologistId: widget.psychologistId,
        psychologistName: widget.psychologistName,
      );
      if (!mounted) return;
      setState(() {
        _genderStats = genderStats;
        _statusCounts = statusCounts;
      });
    } catch (e) {
      debugPrint('Error cargando estadísticas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen Semanal',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Charts
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _AppointmentsChart(
                    db: _db,
                    psychologistId: widget.psychologistId,
                    psychologistName: widget.psychologistName,
                  ),
                  const SizedBox(height: 24),
                  _GenderChart(
                    maleCount: _genderStats['male'] ?? 0,
                    femaleCount: _genderStats['female'] ?? 0,
                    total: _genderStats['total'] ?? 0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right side - Lists
            Expanded(
              flex: 1,
              child: _AppointmentStatusList(
                completed: _statusCounts['completed'] ?? 0,
                pending: _statusCounts['pending'] ?? 0,
                cancelled: _statusCounts['cancelled'] ?? 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AppointmentsChart extends StatefulWidget {
  final DatabaseService db;
  final String? psychologistId;
  final String? psychologistName;

  const _AppointmentsChart({
    required this.db,
    this.psychologistId,
    this.psychologistName,
  });

  @override
  State<_AppointmentsChart> createState() => _AppointmentsChartState();
}

class _AppointmentsChartState extends State<_AppointmentsChart> {
  late final DataNotificationService _notificationService;
  Map<int, int> _weekdayCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Guardamos la referencia para que el dispose use la MISMA instancia.
    _notificationService = context.read<DataNotificationService>();
    _notificationService.addListener(_loadData);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final counts = await widget.db.getAppointmentsByWeekday(
        psychologistId: widget.psychologistId,
        psychologistName: widget.psychologistName,
      );
      if (!mounted) return;
      setState(() {
        _weekdayCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error cargando citas por día: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = _weekdayCounts.values.isEmpty
        ? 1
        : (_weekdayCounts.values.reduce((a, b) => a > b ? a : b) + 2);

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
            'Citas por Día de la Semana',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_weekdayCounts.values.every((v) => v == 0))
            const SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'No hay citas registradas esta semana',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue.toDouble(),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = [
                            'Lun',
                            'Mar',
                            'Mié',
                            'Jue',
                            'Vie',
                            'Sáb',
                            'Dom'
                          ];
                          if (value.toInt() >= 0 &&
                              value.toInt() < days.length) {
                            return Text(
                              days[value.toInt()],
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue > 10 ? 5.0 : 1.0,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(
                        toY: (_weekdayCounts[0] ?? 0).toDouble(),
                        color: const Color(0xFF1E3A5F),
                        width: 20,
                      )
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(
                        toY: (_weekdayCounts[1] ?? 0).toDouble(),
                        color: const Color(0xFF1E3A5F),
                        width: 20,
                      )
                    ]),
                    BarChartGroupData(x: 2, barRods: [
                      BarChartRodData(
                        toY: (_weekdayCounts[2] ?? 0).toDouble(),
                        color: const Color(0xFF1E3A5F),
                        width: 20,
                      )
                    ]),
                    BarChartGroupData(x: 3, barRods: [
                      BarChartRodData(
                        toY: (_weekdayCounts[3] ?? 0).toDouble(),
                        color: const Color(0xFF1E3A5F),
                        width: 20,
                      )
                    ]),
                    BarChartGroupData(x: 4, barRods: [
                      BarChartRodData(
                        toY: (_weekdayCounts[4] ?? 0).toDouble(),
                        color: const Color(0xFF1E3A5F),
                        width: 20,
                      )
                    ]),
                    BarChartGroupData(x: 5, barRods: [
                      BarChartRodData(
                        toY: (_weekdayCounts[5] ?? 0).toDouble(),
                        color: const Color(0xFF1E3A5F),
                        width: 20,
                      )
                    ]),
                    BarChartGroupData(x: 6, barRods: [
                      BarChartRodData(
                        toY: (_weekdayCounts[6] ?? 0).toDouble(),
                        color: const Color(0xFF1E3A5F),
                        width: 20,
                      )
                    ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GenderChart extends StatelessWidget {
  final int maleCount;
  final int femaleCount;
  final int total;

  const _GenderChart({
    required this.maleCount,
    required this.femaleCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final femalePercentage =
        total > 0 ? ((femaleCount / total) * 100).round() : 0;
    final malePercentage = total > 0 ? ((maleCount / total) * 100).round() : 0;

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
            'Pacientes por Género',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 24),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No hay pacientes registrados',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else ...[
            if (femaleCount > 0) ...[
              _GenderBar(
                label: 'Femenino',
                value: femaleCount,
                percentage: femalePercentage,
                color: Colors.pink,
              ),
              const SizedBox(height: 16),
            ],
            if (maleCount > 0)
              _GenderBar(
                label: 'Masculino',
                value: maleCount,
                percentage: malePercentage,
                color: Colors.blue,
              ),
          ],
        ],
      ),
    );
  }
}

class _GenderBar extends StatelessWidget {
  final String label;
  final int value;
  final int percentage;
  final Color color;

  const _GenderBar({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E3A5F),
              ),
            ),
            Text(
              '$value ($percentage%)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 24,
          ),
        ),
      ],
    );
  }
}

class _AppointmentStatusList extends StatelessWidget {
  final int completed;
  final int pending;
  final int cancelled;

  const _AppointmentStatusList({
    required this.completed,
    required this.pending,
    required this.cancelled,
  });

  @override
  Widget build(BuildContext context) {
    final total = completed + pending + cancelled;
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
            'Estado de Citas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No hay citas registradas',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else ...[
            _StatusItem(
              label: 'Completadas',
              value: completed.toString(),
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _StatusItem(
              label: 'Pendientes',
              value: pending.toString(),
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _StatusItem(
              label: 'Canceladas',
              value: cancelled.toString(),
              color: Colors.red,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1E3A5F),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
      ],
    );
  }
}
