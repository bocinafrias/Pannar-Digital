enum AppointmentStatus {
  scheduled,
  completed,
  cancelled,
  rescheduled,
}

class AppointmentModel {
  final String id;
  final String patientId;
  final String psychologistId;
  final DateTime dateTime;
  final String reason;
  final AppointmentStatus status;
  final String? notes;
  final bool?
      attended; // null = no registrado, true = asistió, false = no asistió
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.psychologistId,
    required this.dateTime,
    required this.reason,
    this.status = AppointmentStatus.scheduled,
    this.notes,
    this.attended,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      psychologistId: json['psychologist_id'] as String,
      dateTime: DateTime.parse(json['date_time'] as String),
      reason: json['reason'] as String,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => AppointmentStatus.scheduled,
      ),
      notes: json['notes'] as String?,
      attended: json['attended'] == null
          ? null
          : json['attended'] is bool
              ? json['attended'] as bool
              : (json['attended'] as int) == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'psychologist_id': psychologistId,
      'date_time': dateTime.toIso8601String(),
      'reason': reason,
      'status': status.toString().split('.').last,
      'notes': notes,
      'attended': attended == null ? null : (attended! ? 1 : 0),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? psychologistId,
    DateTime? dateTime,
    String? reason,
    AppointmentStatus? status,
    String? notes,
    bool? attended,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      psychologistId: psychologistId ?? this.psychologistId,
      dateTime: dateTime ?? this.dateTime,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      attended: attended ?? this.attended,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
