import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/report_pdf_service.dart';
import '../services/data_notification_service.dart';
import '../models/talk_model.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseService();
  final _pdfService = ReportPdfService();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGenerating = false;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    // Por defecto, seleccionar el mes actual
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    // Cargar datos después de que el frame se haya renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReportData();
    });
    // Escuchar cambios en los datos para actualizar el reporte
    final notificationService =
        Provider.of<DataNotificationService>(context, listen: false);
    notificationService.addListener(_loadReportData);
  }

  @override
  void dispose() {
    // Remover listener
    final notificationService =
        Provider.of<DataNotificationService>(context, listen: false);
    notificationService.removeListener(_loadReportData);
    super.dispose();
  }

  Future<void> _loadReportData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() => _isGenerating = true);
    try {
      final data = await _db.getMonthlyReportData(
        startDate: _startDate!,
        endDate: _endDate!,
      );
      print('Report data loaded: $data'); // Debug
      setState(() => _reportData = data);
    } catch (e, stackTrace) {
      print('Error loading report data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
      setState(() => _reportData = {});
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, 1);
        // Ajustar fecha fin al último día del mes seleccionado
        if (_endDate != null &&
            _endDate!.month == picked.month &&
            _endDate!.year == picked.year) {
          _endDate = DateTime(picked.year, picked.month + 1, 0);
        }
      });
      _loadReportData();
    }
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final firstDate = _startDate ?? DateTime(now.year - 1, 1, 1);
    final initialDate = _endDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now)
          ? now
          : (initialDate.isBefore(firstDate) ? firstDate : initialDate),
      firstDate: firstDate,
      lastDate: now,
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _loadReportData();
    }
  }

  Future<void> _generatePdf() async {
    if (_startDate == null || _endDate == null || _reportData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un período válido')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final authService = context.read<AuthService>();
      final userName = authService.currentUserModel?.name ?? 'Usuario';

      final pdf = await _pdfService.generateMonthlyReport(
        startDate: _startDate!,
        endDate: _endDate!,
        reportData: _reportData!,
        psychologistName: userName,
        coordinatorName: 'Lic. Deysi Córdova Alejandro',
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
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
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título
                          const Text(
                            'Generación de Reportes Mensuales',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Selector de fechas
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Seleccionar Período',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ListTile(
                                          title: const Text('Fecha de inicio'),
                                          subtitle: Text(
                                            _startDate != null
                                                ? DateFormat('dd/MM/yyyy', 'es')
                                                    .format(_startDate!)
                                                : 'No seleccionada',
                                          ),
                                          trailing:
                                              const Icon(Icons.calendar_today),
                                          onTap: _selectStartDate,
                                        ),
                                      ),
                                      Expanded(
                                        child: ListTile(
                                          title: const Text('Fecha de fin'),
                                          subtitle: Text(
                                            _endDate != null
                                                ? DateFormat('dd/MM/yyyy', 'es')
                                                    .format(_endDate!)
                                                : 'No seleccionada',
                                          ),
                                          trailing:
                                              const Icon(Icons.calendar_today),
                                          onTap: _selectEndDate,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isGenerating ? null : _generatePdf,
                                      icon: _isGenerating
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(Icons.picture_as_pdf),
                                      label: Text(_isGenerating
                                          ? 'Generando...'
                                          : 'Generar Reporte PDF'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1E3A5F),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Vista previa de estadísticas
                          if (_isGenerating)
                            const Expanded(
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_reportData != null &&
                              _reportData!.isNotEmpty)
                            Expanded(
                              child: _buildStatisticsPreview(),
                            )
                          else
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Selecciona un período para ver las estadísticas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsPreview() {
    final totalAppointments = _reportData!['totalAppointments'] as int? ?? 0;
    final maleCount = _reportData!['maleCount'] as int? ?? 0;
    final femaleCount = _reportData!['femaleCount'] as int? ?? 0;
    final uniqueCommunities = _reportData!['uniqueCommunities'] as int? ?? 0;
    final communityCounts =
        (_reportData!['communityCounts'] as Map<String, dynamic>?)
                ?.map((key, value) => MapEntry(key, value as int)) ??
            <String, int>{};

    List<TalkModel> talks = [];
    try {
      final talksList = _reportData!['talks'] as List?;
      if (talksList != null) {
        talks = talksList
            .map((t) => TalkModel.fromJson(t as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error parsing talks: $e');
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de estadísticas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen del Período',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Atendidos',
                          '$totalAppointments',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Hombres',
                          '$maleCount',
                          Icons.male,
                          Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Mujeres',
                          '$femaleCount',
                          Icons.female,
                          Colors.pink,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Comunidades',
                          '$uniqueCommunities',
                          Icons.location_city,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Comunidades
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comunidades Beneficiadas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: communityCounts.length,
                      itemBuilder: (context, index) {
                        final entry = communityCounts.entries.elementAt(index);
                        return ListTile(
                          title: Text(entry.key),
                          trailing: Text(
                            '${entry.value} pacientes',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Pláticas
          if (talks.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pláticas Realizadas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: talks.length,
                      itemBuilder: (context, index) {
                        final talk = talks[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(talk.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Institución: ${talk.educationalInstitution}'),
                                Text('Ubicación: ${talk.schoolLocation}'),
                                Text(
                                    'Alumnos beneficiados: ${talk.studentsBenefited}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
