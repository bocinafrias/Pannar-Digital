import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/talk_model.dart';

class ReportPdfService {
  static const String letterheadAsset =
      'assets/images/membrete_carta.png';

  Future<pw.Document> generateMonthlyReport({
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> reportData,
    required String psychologistName,
    String? coordinatorName,
  }) async {
    final pdf = pw.Document();

    // Cargar imagen de membrete (fondo)
    pw.MemoryImage? letterheadImage;

    try {
      final letterheadBytes = await rootBundle.load(letterheadAsset);
      letterheadImage = pw.MemoryImage(letterheadBytes.buffer.asUint8List());
    } catch (e) {
      print('No se pudo cargar $letterheadAsset: $e');
    }

    // Obtener datos del reporte
    final totalAppointments = reportData['totalAppointments'] as int;
    final maleCount = reportData['maleCount'] as int;
    final femaleCount = reportData['femaleCount'] as int;
    final communityCounts = reportData['communityCounts'] as Map<String, int>;
    final uniqueCommunities = reportData['uniqueCommunities'] as int;
    final talks = (reportData['talks'] as List)
        .map((t) => TalkModel.fromJson(t))
        .toList();
    final weekdayCountsMap =
        reportData['weekdayCounts'] as Map<dynamic, dynamic>?;
    final weekdayCounts = <int, int>{};
    if (weekdayCountsMap != null) {
      weekdayCountsMap.forEach((key, value) {
        final intKey = key is int ? key : int.parse(key.toString());
        weekdayCounts[intKey] = (value as num).toInt();
      });
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.zero,
          buildBackground: (context) {
            if (letterheadImage == null) return pw.SizedBox();
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(
                letterheadImage,
                fit: pw.BoxFit.cover,
              ),
            );
          },
        ),
        build: (pw.Context context) {
          return [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(50, 140, 50, 70),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Encabezado del reporte
                  _buildReportHeader(startDate, endDate),
                  pw.SizedBox(height: 20),

                  // Texto introductorio
                  _buildIntroductoryText(
                      startDate, endDate, psychologistName),
                  pw.SizedBox(height: 30),

                  // Estadísticas de género y comunidades
                  _buildGenderAndCommunityStats(
                    maleCount,
                    femaleCount,
                    uniqueCommunities,
                  ),
                  pw.SizedBox(height: 30),

                  // Tabla de comunidades beneficiadas
                  _buildCommunityTable(communityCounts, totalAppointments),
                  pw.SizedBox(height: 30),

                  // Tabla de pláticas
                  if (talks.isNotEmpty) ...[
                    _buildTalksTable(talks),
                    pw.SizedBox(height: 30),
                  ],

                  // Sección de estadísticas y gráficos
                  _buildStatisticsCharts(reportData, weekdayCounts),
                  pw.SizedBox(height: 30),

                  // Sección de evidencias fotográficas
                  _buildPhotoEvidenceSection(),
                  pw.SizedBox(height: 30),

                  // Firmas
                  _buildSignatures(psychologistName, coordinatorName),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildReportHeader(DateTime startDate, DateTime endDate) {
    final dateFormat = DateFormat('MMMM', 'es');
    final startMonth = dateFormat.format(startDate);
    final endMonth = dateFormat.format(endDate);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Comisión: XIII Atención a grupos vulnerables, adultos mayor y personal con características Especiales.',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Área que informa: Programa de Atención a Niñas, Niños y Adolescentes en Riesgo. PANNAR.',
          style: pw.TextStyle(fontSize: 11, color: PdfColors.black),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Periodo: $startMonth-$endMonth',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Mes: ${_capitalizeMonth(dateFormat.format(startDate))}',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildIntroductoryText(
    DateTime startDate,
    DateTime endDate,
    String psychologistName,
  ) {
    final dateFormat = DateFormat('MMMM', 'es');

    return pw.Text(
      'Durante el periodo comprendido del ${startDate.day} al ${endDate.day} de ${_capitalizeMonth(dateFormat.format(startDate))} del presente año, se llevaron a cabo actividades correspondientes al área de atención psicológica. En este lapso, se impartieron terapias psicológicas, dichas intervenciones fueron realizadas por $psychologistName.',
      style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
      textAlign: pw.TextAlign.left,
    );
  }

  pw.Widget _buildGenderAndCommunityStats(
    int maleCount,
    int femaleCount,
    int uniqueCommunities,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TOTAL, DE COMUNIDADES ATENDIDAS Y GÉNERO:',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Hombres',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
              ),
            ),
            pw.Text(
              '$maleCount',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Mujeres',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
              ),
            ),
            pw.Text(
              '$femaleCount',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Comunidades',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
              ),
            ),
            pw.Text(
              '$uniqueCommunities',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildCommunityTable(
    Map<String, int> communityCounts,
    int total,
  ) {
    final sortedCommunities = communityCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'METAS ALCANZADAS EN ATENCIONES PSICOLOGICAS:',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            // Encabezado
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Comunidades beneficiadas con consultas psicológicas',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Número de pacientes',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            // Filas de datos
            ...sortedCommunities.map((entry) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      entry.key,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      '${entry.value}',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              );
            }).toList(),
            // Fila de total
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'TOTAL:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    '$total',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTalksTable(List<TalkModel> talks) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'METAS ALCANZADAS EN PLATICAS.',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(0.8),
          },
          children: [
            // Encabezado
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('NOMBRE DE LA PLATICA', isHeader: true),
                _buildTableCell('INSTITUCIÓN EDUCATIVA BENEFICIADA',
                    isHeader: true),
                _buildTableCell('TEMÁTICA ABORDADA', isHeader: true),
                _buildTableCell('UBICACIÓN DE LA ESCUELA', isHeader: true),
                _buildTableCell('NUMERO DE ALUMNOS BENEFICIADOS',
                    isHeader: true),
              ],
            ),
            // Filas de datos
            ...talks.map((talk) {
              return pw.TableRow(
                children: [
                  _buildTableCell(talk.name),
                  _buildTableCell(talk.educationalInstitution),
                  _buildTableCell(talk.topic),
                  _buildTableCell(talk.schoolLocation),
                  _buildTableCell('${talk.studentsBenefited}'),
                ],
              );
            }).toList(),
            // Fila de total
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('TOTAL:', isHeader: true, colspan: 4),
                _buildTableCell(
                  '${talks.fold(0, (sum, talk) => sum + talk.studentsBenefited)}',
                  isHeader: true,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text,
      {bool isHeader = false, int colspan = 1}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildPhotoEvidenceSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'EVIDENCIAS FOTOGRAFICAS',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 20),
        // Espacio para fotos (se puede mejorar con imágenes reales)
        pw.Container(
          height: 100,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            color: PdfColors.grey100,
          ),
          child: pw.Center(
            child: pw.Text(
              '[Espacio para evidencias fotográficas]',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSignatures(String psychologistName, String? coordinatorName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Elaboró:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'Jefe de área PANNAR.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        if (coordinatorName != null)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Autorizó:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Text(
                'Coordinadora del Sistema DIF Jalpa de Méndez.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
      ],
    );
  }

  String _capitalizeMonth(String month) {
    if (month.isEmpty) return month;
    return month[0].toUpperCase() + month.substring(1);
  }

  pw.Widget _buildStatisticsCharts(
      Map<String, dynamic> reportData, Map<int, int> weekdayCounts) {
    final maleCount = reportData['maleCount'] as int;
    final femaleCount = reportData['femaleCount'] as int;
    final totalPatients = maleCount + femaleCount;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ESTADÍSTICAS Y GRÁFICOS',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 20),

        // Gráfico de género
        _buildGenderChart(maleCount, femaleCount, totalPatients),
        pw.SizedBox(height: 30),

        // Gráfico de citas por día de la semana
        _buildWeekdayChart(weekdayCounts),
        pw.SizedBox(height: 30),
      ],
    );
  }

  pw.Widget _buildGenderChart(int maleCount, int femaleCount, int total) {
    final maxValue = total > 0 ? total : 1;
    final malePercentage = total > 0 ? (maleCount / total * 100).round() : 0;
    final femalePercentage =
        total > 0 ? (femaleCount / total * 100).round() : 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Distribución de Pacientes por Género',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 15),
        if (total > 0) ...[
          // Barra de Femenino
          if (femaleCount > 0) ...[
            _buildGenderBarChart(
              'Femenino',
              femaleCount,
              femalePercentage,
              PdfColors.pink300,
              maxValue,
            ),
            pw.SizedBox(height: 10),
          ],

          // Barra de Masculino
          if (maleCount > 0) ...[
            _buildGenderBarChart(
              'Masculino',
              maleCount,
              malePercentage,
              PdfColors.blue300,
              maxValue,
            ),
          ],
        ] else
          pw.Text(
            'No hay datos disponibles',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
      ],
    );
  }

  pw.Widget _buildGenderBarChart(
    String label,
    int count,
    int percentage,
    PdfColor color,
    int maxValue,
  ) {
    final barWidth = ((count / maxValue) * 100) * 5;

    return pw.Row(
      children: [
        pw.Container(
          width: 80,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.Expanded(
          child: pw.Stack(
            children: [
              pw.Container(
                height: 20,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
              pw.Container(
                height: 20,
                width: barWidth,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          '$count ($percentage%)',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildWeekdayChart(Map<int, int> weekdayCounts) {
    final weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    final maxValue = weekdayCounts.values.isEmpty
        ? 1
        : weekdayCounts.values.reduce((a, b) => a > b ? a : b);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Distribución de Citas por Día de la Semana',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 15),
        if (weekdayCounts.isNotEmpty && maxValue > 0) ...[
          for (int i = 0; i < 7; i++)
            if (weekdayCounts[i] != null && weekdayCounts[i]! > 0) ...[
              _buildWeekdayBarChart(
                weekdays[i],
                weekdayCounts[i]!,
                PdfColors.blue400,
                maxValue,
              ),
              pw.SizedBox(height: 8),
            ],
        ] else
          pw.Text(
            'No hay datos disponibles',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
      ],
    );
  }

  pw.Widget _buildWeekdayBarChart(
    String label,
    int count,
    PdfColor color,
    int maxValue,
  ) {
    final barWidth = ((count / maxValue) * 100) * 5;

    return pw.Row(
      children: [
        pw.Container(
          width: 80,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.Expanded(
          child: pw.Stack(
            children: [
              pw.Container(
                height: 20,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
              pw.Container(
                height: 20,
                width: barWidth,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          '$count',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }
}
