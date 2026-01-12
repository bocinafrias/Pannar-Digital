enum ReportType {
  monthly,
  custom,
  psychologist,
  patient,
}

class ReportModel {
  final String id;
  final ReportType type;
  final String title;
  final Map<String, dynamic> data;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? psychologistId;
  final DateTime createdAt;
  final String? filePath;

  ReportModel({
    required this.id,
    required this.type,
    required this.title,
    required this.data,
    this.startDate,
    this.endDate,
    this.psychologistId,
    required this.createdAt,
    this.filePath,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      type: ReportType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ReportType.custom,
      ),
      title: json['title'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      psychologistId: json['psychologist_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      filePath: json['file_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'title': title,
      'data': data,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'psychologist_id': psychologistId,
      'created_at': createdAt.toIso8601String(),
      'file_path': filePath,
    };
  }
}
