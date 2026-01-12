import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/talk_model.dart';

class ReportWordService {
  Future<File> generateMonthlyReport({
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> reportData,
    required String psychologistName,
    String? coordinatorName,
  }) async {
    // Obtener datos del reporte
    final totalAppointments = reportData['totalAppointments'] as int? ?? 0;
    final maleCount = reportData['maleCount'] as int? ?? 0;
    final femaleCount = reportData['femaleCount'] as int? ?? 0;
    final communityCounts =
        (reportData['communityCounts'] as Map<String, dynamic>?)
                ?.map((key, value) => MapEntry(key, value as int)) ??
            <String, int>{};
    final uniqueCommunities = reportData['uniqueCommunities'] as int? ?? 0;
    final talks = (reportData['talks'] as List?)
            ?.map((t) => TalkModel.fromJson(t as Map<String, dynamic>))
            .toList() ??
        <TalkModel>[];

    // Generar contenido HTML que Word puede abrir
    final htmlContent = _generateHtmlContent(
      startDate,
      endDate,
      totalAppointments,
      maleCount,
      femaleCount,
      uniqueCommunities,
      communityCounts,
      talks,
      psychologistName,
      coordinatorName,
    );

    // Guardar como archivo .doc (HTML con extensión .doc funciona en Word)
    final directory = await getTemporaryDirectory();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final fileName = 'Reporte_PANNAR_${dateFormat.format(startDate)}.doc';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(htmlContent);

    return file;
  }

  String _generateHtmlContent(
    DateTime startDate,
    DateTime endDate,
    int totalAppointments,
    int maleCount,
    int femaleCount,
    int uniqueCommunities,
    Map<String, int> communityCounts,
    List<TalkModel> talks,
    String psychologistName,
    String? coordinatorName,
  ) {
    final dateFormat = DateFormat('MMMM', 'es');
    final startMonth = _capitalizeMonth(dateFormat.format(startDate));
    final endMonth = _capitalizeMonth(dateFormat.format(endDate));
    final monthName = _capitalizeMonth(dateFormat.format(startDate));

    final sb = StringBuffer();
    sb.writeln('<!DOCTYPE html>');
    sb.writeln(
        '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">');
    sb.writeln('<head>');
    sb.writeln('<meta charset="utf-8">');
    sb.writeln('<meta name="ProgId" content="Word.Document">');
    sb.writeln('<meta name="Generator" content="Microsoft Word">');
    sb.writeln('<meta name="Originator" content="Microsoft Word">');
    sb.writeln('<title>Reporte Mensual PANNAR</title>');
    sb.writeln('<style>');
    sb.writeln('@page {');
    sb.writeln('  size: 21.59cm 27.94cm;');
    sb.writeln('  margin: 2.5cm 2.5cm 2.5cm 2.5cm;');
    sb.writeln('  mso-header-margin: 1.27cm;');
    sb.writeln('  mso-footer-margin: 1.27cm;');
    sb.writeln('}');
    sb.writeln('body {');
    sb.writeln('  font-family: "Times New Roman", serif;');
    sb.writeln('  font-size: 12pt;');
    sb.writeln('  margin: 0;');
    sb.writeln('  padding: 0;');
    sb.writeln('  line-height: 1.5;');
    sb.writeln('}');
    sb.writeln('.letterhead {');
    sb.writeln('  margin-bottom: 30px;');
    sb.writeln('  padding-bottom: 15px;');
    sb.writeln('  border-bottom: 2px solid #D4A574;');
    sb.writeln('}');
    sb.writeln('.letterhead-table {');
    sb.writeln('  width: 100%;');
    sb.writeln('  border-collapse: collapse;');
    sb.writeln('  margin-bottom: 10px;');
    sb.writeln('}');
    sb.writeln('.letterhead-cell {');
    sb.writeln('  vertical-align: top;');
    sb.writeln('  padding: 5px;');
    sb.writeln('}');
    sb.writeln('.municipio-name {');
    sb.writeln('  color: #8B1A1A;');
    sb.writeln('  font-size: 18pt;');
    sb.writeln('  font-weight: bold;');
    sb.writeln('  margin: 0;');
    sb.writeln('}');
    sb.writeln('.letterhead-text {');
    sb.writeln('  font-size: 10pt;');
    sb.writeln('  margin: 2px 0;');
    sb.writeln('  line-height: 1.3;');
    sb.writeln('}');
    sb.writeln('h2 {');
    sb.writeln('  color: #000;');
    sb.writeln('  font-size: 11pt;');
    sb.writeln('  font-weight: bold;');
    sb.writeln('  margin-top: 15px;');
    sb.writeln('  margin-bottom: 8px;');
    sb.writeln('}');
    sb.writeln('p {');
    sb.writeln('  font-size: 10pt;');
    sb.writeln('  text-align: justify;');
    sb.writeln('  margin: 8px 0;');
    sb.writeln('  line-height: 1.6;');
    sb.writeln('}');
    sb.writeln('table {');
    sb.writeln('  border-collapse: collapse;');
    sb.writeln('  width: 100%;');
    sb.writeln('  margin: 10px 0;');
    sb.writeln('  font-size: 9pt;');
    sb.writeln('}');
    sb.writeln('td, th {');
    sb.writeln('  border: 1px solid #000;');
    sb.writeln('  padding: 6px;');
    sb.writeln('  text-align: left;');
    sb.writeln('}');
    sb.writeln('th {');
    sb.writeln('  background-color: #E0E0E0;');
    sb.writeln('  font-weight: bold;');
    sb.writeln('}');
    sb.writeln('.chart-container {');
    sb.writeln('  margin: 15px 0;');
    sb.writeln('  padding: 10px;');
    sb.writeln('}');
    sb.writeln('.chart-bar {');
    sb.writeln('  display: flex;');
    sb.writeln('  align-items: center;');
    sb.writeln('  margin: 8px 0;');
    sb.writeln('}');
    sb.writeln('.chart-label {');
    sb.writeln('  width: 100px;');
    sb.writeln('  font-size: 9pt;');
    sb.writeln('}');
    sb.writeln('.chart-bar-visual {');
    sb.writeln('  height: 25px;');
    sb.writeln('  display: inline-block;');
    sb.writeln('  margin: 0 10px;');
    sb.writeln('}');
    sb.writeln('.chart-value {');
    sb.writeln('  font-size: 9pt;');
    sb.writeln('  font-weight: bold;');
    sb.writeln('}');
    sb.writeln('.signature-section {');
    sb.writeln('  margin-top: 50px;');
    sb.writeln('}');
    sb.writeln('.signature-table {');
    sb.writeln('  width: 100%;');
    sb.writeln('  border: none;');
    sb.writeln('}');
    sb.writeln('.signature-cell {');
    sb.writeln('  border: none;');
    sb.writeln('  width: 50%;');
    sb.writeln('  vertical-align: top;');
    sb.writeln('}');
    sb.writeln('</style>');
    sb.writeln('</head>');
    sb.writeln('<body>');

    // Membrete mejorado
    sb.writeln('<div class="letterhead">');
    sb.writeln('<table class="letterhead-table">');
    sb.writeln('<tr>');
    sb.writeln('<td class="letterhead-cell" style="width: 30%;">');
    sb.writeln('<p class="municipio-name">Jalpa de Méndez</p>');
    sb.writeln(
        '<p class="letterhead-text"><strong>H. AYUNTAMIENTO CONSTITUCIONAL</strong></p>');
    sb.writeln('<p class="letterhead-text">2024-2027</p>');
    sb.writeln(
        '<p class="letterhead-text">Transformación, Justicia y Dignidad</p>');
    sb.writeln('</td>');
    sb.writeln(
        '<td class="letterhead-cell" style="width: 40%; text-align: center;">');
    sb.writeln(
        '<p class="letterhead-text" style="font-size: 20pt; font-weight: bold; color: #8B1A1A; margin: 0;">DIF</p>');
    sb.writeln(
        '<p class="letterhead-text" style="font-weight: bold;">MUNICIPAL</p>');
    sb.writeln('<p class="letterhead-text">JALPA DE MÉNDEZ 2024-2027</p>');
    sb.writeln('</td>');
    sb.writeln(
        '<td class="letterhead-cell" style="width: 30%; text-align: right;">');
    sb.writeln(
        '<p class="letterhead-text" style="font-size: 16pt; font-weight: bold;">2025</p>');
    sb.writeln('<p class="letterhead-text">Año de las</p>');
    sb.writeln(
        '<p class="letterhead-text" style="font-weight: bold;">Mujeres Indígenas</p>');
    sb.writeln('</td>');
    sb.writeln('</tr>');
    sb.writeln('</table>');
    sb.writeln('</div>');

    // Encabezado del reporte
    sb.writeln(
        '<h2>Comisión: XIII Atención a grupos vulnerables, adultos mayor y personal con características Especiales.</h2>');
    sb.writeln(
        '<p>Área que informa: Programa de Atención a Niñas, Niños y Adolescentes en Riesgo. PANNAR.</p>');
    sb.writeln('<p><strong>Periodo: $startMonth-$endMonth</strong></p>');
    sb.writeln('<p><strong>Mes: $startMonth</strong></p>');

    // Texto introductorio
    sb.writeln(
        '<p>Durante el periodo comprendido del ${startDate.day} al ${endDate.day} de $monthName del presente año, se llevaron a cabo actividades correspondientes al área de atención psicológica. En este lapso, se impartieron terapias psicológicas, dichas intervenciones fueron realizadas por $psychologistName.</p>');

    // Estadísticas de género y comunidades
    sb.writeln('<h2>TOTAL, DE COMUNIDADES ATENDIDAS Y GÉNERO:</h2>');
    sb.writeln('<table>');
    sb.writeln(
        '<tr><td>Hombres</td><td style="text-align: right;"><strong>$maleCount</strong></td></tr>');
    sb.writeln(
        '<tr><td>Mujeres</td><td style="text-align: right;"><strong>$femaleCount</strong></td></tr>');
    sb.writeln(
        '<tr><td>Comunidades</td><td style="text-align: right;"><strong>$uniqueCommunities</strong></td></tr>');
    sb.writeln('</table>');

    // Tabla de comunidades beneficiadas
    sb.writeln('<h2>METAS ALCANZADAS EN ATENCIONES PSICOLOGICAS:</h2>');
    sb.writeln('<table>');
    sb.writeln(
        '<tr><th>Comunidades beneficiadas con consultas psicológicas</th><th>Número de pacientes</th></tr>');

    final sortedCommunities = communityCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedCommunities) {
      sb.writeln(
          '<tr><td>${entry.key}</td><td style="text-align: center;">${entry.value}</td></tr>');
    }

    sb.writeln(
        '<tr><th>TOTAL:</th><th style="text-align: center;">$totalAppointments</th></tr>');
    sb.writeln('</table>');

    // Tabla de pláticas
    if (talks.isNotEmpty) {
      sb.writeln('<h2>METAS ALCANZADAS EN PLATICAS:</h2>');
      sb.writeln('<table>');
      sb.writeln('<tr>');
      sb.writeln('<th>NOMBRE DE LA PLATICA</th>');
      sb.writeln('<th>INSTITUCIÓN EDUCATIVA BENEFICIADA</th>');
      sb.writeln('<th>TEMÁTICA ABORDADA</th>');
      sb.writeln('<th>UBICACIÓN DE LA ESCUELA</th>');
      sb.writeln('<th>NUMERO DE ALUMNOS BENEFICIADOS</th>');
      sb.writeln('</tr>');

      for (final talk in talks) {
        sb.writeln('<tr>');
        sb.writeln('<td>${talk.name}</td>');
        sb.writeln('<td>${talk.educationalInstitution}</td>');
        sb.writeln('<td>${talk.topic}</td>');
        sb.writeln('<td>${talk.schoolLocation}</td>');
        sb.writeln(
            '<td style="text-align: center;">${talk.studentsBenefited}</td>');
        sb.writeln('</tr>');
      }

      final totalStudents =
          talks.fold(0, (sum, talk) => sum + talk.studentsBenefited);
      sb.writeln('<tr>');
      sb.writeln('<th colspan="4">TOTAL:</th>');
      sb.writeln('<th style="text-align: center;">$totalStudents</th>');
      sb.writeln('</tr>');
      sb.writeln('</table>');
    }

    // Estadísticas con gráficos
    sb.writeln('<h2>ESTADÍSTICAS Y GRÁFICOS</h2>');
    sb.writeln(
        '<h3 style="font-size: 10pt; font-weight: bold; margin-top: 10px;">Distribución de Pacientes por Género</h3>');
    final total = maleCount + femaleCount;
    if (total > 0) {
      final malePercentage = ((maleCount / total) * 100).round();
      final femalePercentage = ((femaleCount / total) * 100).round();
      final maxValue = total > 0 ? total : 1;

      // Gráfico de barras usando SVG
      sb.writeln('<div class="chart-container">');

      // Barra Femenino
      if (femaleCount > 0) {
        final barWidth = ((femaleCount / maxValue) * 100).clamp(0, 100);
        sb.writeln('<div class="chart-bar">');
        sb.writeln('<span class="chart-label">Femenino:</span>');
        sb.writeln(
            '<svg width="300" height="25" style="vertical-align: middle;">');
        sb.writeln(
            '<rect x="0" y="0" width="300" height="25" fill="#E0E0E0" rx="3"/>');
        sb.writeln(
            '<rect x="0" y="0" width="${300 * barWidth / 100}" height="25" fill="#FF69B4" rx="3"/>');
        sb.writeln('</svg>');
        sb.writeln(
            '<span class="chart-value" style="margin-left: 10px;">$femaleCount ($femalePercentage%)</span>');
        sb.writeln('</div>');
      }

      // Barra Masculino
      if (maleCount > 0) {
        final barWidth = ((maleCount / maxValue) * 100).clamp(0, 100);
        sb.writeln('<div class="chart-bar">');
        sb.writeln('<span class="chart-label">Masculino:</span>');
        sb.writeln(
            '<svg width="300" height="25" style="vertical-align: middle;">');
        sb.writeln(
            '<rect x="0" y="0" width="300" height="25" fill="#E0E0E0" rx="3"/>');
        sb.writeln(
            '<rect x="0" y="0" width="${300 * barWidth / 100}" height="25" fill="#4169E1" rx="3"/>');
        sb.writeln('</svg>');
        sb.writeln(
            '<span class="chart-value" style="margin-left: 10px;">$maleCount ($malePercentage%)</span>');
        sb.writeln('</div>');
      }

      sb.writeln('</div>');
    } else {
      sb.writeln('<p>No hay datos disponibles</p>');
    }

    // Evidencias fotográficas
    sb.writeln('<h2>EVIDENCIAS FOTOGRAFICAS</h2>');
    sb.writeln('<p><em>[Espacio para evidencias fotográficas]</em></p>');

    // Firmas
    sb.writeln('<div class="signature-section">');
    sb.writeln('<table class="signature-table">');
    sb.writeln('<tr>');
    sb.writeln('<td class="signature-cell">');
    sb.writeln('<p><strong>Elaboró:</strong></p>');
    sb.writeln('<br><br>');
    sb.writeln('<p>$psychologistName<br>Jefe de área PANNAR.</p>');
    sb.writeln('</td>');
    if (coordinatorName != null) {
      sb.writeln('<td class="signature-cell">');
      sb.writeln('<p><strong>Autorizó:</strong></p>');
      sb.writeln('<br><br>');
      sb.writeln(
          '<p>$coordinatorName<br>Coordinadora del Sistema DIF Jalpa de Méndez.</p>');
      sb.writeln('</td>');
    }
    sb.writeln('</tr>');
    sb.writeln('</table>');
    sb.writeln('</div>');

    sb.writeln('</body>');
    sb.writeln('</html>');

    return sb.toString();
  }

  String _capitalizeMonth(String month) {
    if (month.isEmpty) return month;
    return month[0].toUpperCase() + month.substring(1);
  }
}
