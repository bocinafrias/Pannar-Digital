import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/database_service.dart';
import '../services/report_pdf_service.dart';
import '../services/auth_service.dart';

class ReportGeneratorDialog extends StatefulWidget {
  const ReportGeneratorDialog({super.key});

  @override
  State<ReportGeneratorDialog> createState() => _ReportGeneratorDialogState();
}

class _ReportGeneratorDialogState extends State<ReportGeneratorDialog> {
  final _db = DatabaseService();
  final _pdfService = ReportPdfService();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGenerating = false;
  double _progress = 0.0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    // Por defecto, seleccionar el mes actual
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _selectStartDate() async {
    try {
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
          if (_endDate != null &&
              _endDate!.month == picked.month &&
              _endDate!.year == picked.year) {
            _endDate = DateTime(picked.year, picked.month + 1, 0);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar fecha: $e')),
        );
      }
    }
  }

  Future<void> _selectEndDate() async {
    try {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar fecha: $e')),
        );
      }
    }
  }

  Future<String> _getDownloadsPath() async {
    // En Windows, usar la carpeta de Descargas del usuario
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    return path.join(userProfile, 'Downloads');
  }

  Future<void> _generateAndSaveReport() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un período válido')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _statusMessage = 'Obteniendo datos del período seleccionado...';
    });

    try {
      // Paso 1: Obtener datos (20%)
      final reportData = await _db.getMonthlyReportData(
        startDate: _startDate!,
        endDate: _endDate!,
      );
      setState(() {
        _progress = 0.2;
        _statusMessage = 'Generando documento PDF...';
      });

      // Paso 2: Generar PDF (50%)
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      final userName = authService.currentUserModel?.name ?? 'Usuario';

      final pdfDocument = await _pdfService.generateMonthlyReport(
        startDate: _startDate!,
        endDate: _endDate!,
        reportData: reportData,
        psychologistName: userName,
        coordinatorName: 'Lic. Deysi Córdova Alejandro',
      );
      setState(() {
        _progress = 0.7;
        _statusMessage = 'Guardando archivo en Descargas...';
      });

      // Paso 3: Guardar en Descargas (80%)
      final pdfBytes = await pdfDocument.save();
      final downloadsPath = await _getDownloadsPath();
      // Formato de fecha manual para evitar problemas con locale
      final year = _startDate!.year;
      final month = _startDate!.month.toString().padLeft(2, '0');
      final fileName = 'Reporte_Mensual_${year}_$month.pdf';
      final filePath = path.join(downloadsPath, fileName);

      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      setState(() {
        _progress = 1.0;
        _statusMessage = '¡Reporte generado exitosamente!';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reporte guardado en: $filePath'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Abrir carpeta',
              onPressed: () {
                // Abrir el explorador de archivos en Windows
                Process.run('explorer', [downloadsPath]);
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error generando reporte: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar el reporte: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Generar Reporte Mensual',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isGenerating
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!_isGenerating) ...[
                // Selector de fechas
                _DateSelector(
                  label: 'Fecha de Inicio',
                  selectedDate: _startDate,
                  onTap: _selectStartDate,
                ),
                const SizedBox(height: 16),
                _DateSelector(
                  label: 'Fecha de Fin',
                  selectedDate: _endDate,
                  onTap: _selectEndDate,
                ),
                const SizedBox(height: 24),

                // Botón generar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generateAndSaveReport,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Generar y Guardar Reporte'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ] else ...[
                // Indicador de progreso
                Column(
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1E3A5F)),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final VoidCallback onTap;

  const _DateSelector({
    required this.label,
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedDate != null
                      ? '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}'
                      : 'No seleccionada',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
