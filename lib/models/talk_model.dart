class TalkModel {
  final String id;
  final String name;
  final String educationalInstitution;
  final String topic;
  final String schoolLocation;
  final int studentsBenefited;
  final DateTime date;
  final String? psychologistId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TalkModel({
    required this.id,
    required this.name,
    required this.educationalInstitution,
    required this.topic,
    required this.schoolLocation,
    required this.studentsBenefited,
    required this.date,
    this.psychologistId,
    required this.createdAt,
    this.updatedAt,
  });

  factory TalkModel.fromJson(Map<String, dynamic> json) {
    return TalkModel(
      id: json['id'] as String,
      name: json['name'] as String,
      educationalInstitution: json['educational_institution'] as String,
      topic: json['topic'] as String,
      schoolLocation: json['school_location'] as String,
      studentsBenefited: json['students_benefited'] as int,
      date: DateTime.parse(json['date'] as String),
      psychologistId: json['psychologist_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'educational_institution': educationalInstitution,
      'topic': topic,
      'school_location': schoolLocation,
      'students_benefited': studentsBenefited,
      'date': date.toIso8601String(),
      'psychologist_id': psychologistId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  TalkModel copyWith({
    String? id,
    String? name,
    String? educationalInstitution,
    String? topic,
    String? schoolLocation,
    int? studentsBenefited,
    DateTime? date,
    String? psychologistId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TalkModel(
      id: id ?? this.id,
      name: name ?? this.name,
      educationalInstitution:
          educationalInstitution ?? this.educationalInstitution,
      topic: topic ?? this.topic,
      schoolLocation: schoolLocation ?? this.schoolLocation,
      studentsBenefited: studentsBenefited ?? this.studentsBenefited,
      date: date ?? this.date,
      psychologistId: psychologistId ?? this.psychologistId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
